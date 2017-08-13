#' Compute pooled standard deviation
#' 
#' @param formula  A formula of the type \code{out ~ group} where \code{out} is
#'   the outcome variable and \code{group} is the grouping variable. Note the
#'   grouping variable must only include only two groups.
#' @param data The data frame that the data in the formula come from.
#' @importFrom stats var
#' @export
#' @examples
#' pooled_sd(math ~ condition, star)
#' pooled_sd(reading ~ sex, star)

pooled_sd <- function(formula, data) {
	splt <- parse_form(formula, data)

	vars <- vapply(splt, var, na.rm = TRUE, numeric(1))
	ns <- vapply(splt, length, numeric(1))

	pooled <- function(v) {
		sqrt((((ns[v[1]] - 1)*vars[v[1]]) + ((ns[v[2]] - 1)*vars[v[2]])) / 
			(sum(ns[v]) - 2))
	}
tidy_out(names(splt), pooled)
}

#' Compute mean differences by various quantiles
#' 
#' @param formula  A formula of the type \code{out ~ group} where \code{out} is
#'   the outcome variable and \code{group} is the grouping variable. Note the
#'   grouping variable must only include only two groups.
#' @param data The data frame that the data in the formula come from.
#' @param qtiles Quantile bins for calculating mean differences
#' @importFrom stats quantile
#' @importFrom utils combn
#' @export
#' @examples
#' qtile_mean_diffs(reading ~ condition, star)
#' 
#' qtile_mean_diffs(reading ~ condition, 
#' 		star, 
#' 		qtiles = seq(0, 1, .2))


qtile_mean_diffs <- function(formula, data, qtiles = seq(0, 1, .33)) {
	splt <- parse_form(formula, data)
	qtile_l <- lapply(splt, function(x) {
		split(x, cut(x, quantile(x, qtiles, na.rm = TRUE)))
	})

	mean_diffs <- function(v) {
		Map(function(x, y) mean(y, na.rm = TRUE) - mean(x, na.rm = TRUE),
			qtile_l[[ v[1] ]], 
			qtile_l[[ v[2] ]])
	}
	td <- tidy_out(names(qtile_l), mean_diffs)	
	td$estimate <- unlist(td$estimate)
	
	low_qtiles <- qtiles[-length(qtiles)]
	high_qtiles <- qtiles[-1]

	td$cut <- rep(rep(low_qtiles, each = length(combn(names(splt), 2)) / 2), 2)
	td$high_qtile <- rep(rep(high_qtiles, 
						each = length(combn(names(splt), 2)) / 2), 2)
	names(td)[3] <- "low_qtile"

td[ ,c(1:3, 5, 4)]
}

qtile_n <- function(formula, data, qtiles = seq(0, 1, .33)) {
	splt <- parse_form(formula, data)
	qtile_l <- lapply(splt, function(x) {
		split(x, cut(x, quantile(x, qtiles, na.rm = TRUE)))
	})
	ns <- lapply(qtile_l, function(x) vapply(x, length, numeric(1)))
	ns <- data.frame(group = rep(names(ns), each = length(ns[[1]])),
			   low_qtile = qtiles[-length(qtiles)],
			   high_qtile = qtiles[-1],		   
			   n = unlist(ns))
ns
}

se_es <- function(n1, n2, d) {
		sqrt((n1 + n2)/(n1*n2) + d^2/(2*((n1 + n2))))
}

#' Compute effect sizes by quantile bins
#' 
#' Returns a data frame with the estimated effect size by the provided 
#' percentiles. Currently, the effect size is equivalent to Cohen's d, but 
#' future development will allow this to vary.
#' 
#' @param formula  A formula of the type \code{out ~ group} where \code{out} is
#'   the outcome variable and \code{group} is the grouping variable. Note the
#'   grouping variable must only include only two groups.
#' @param data The data frame that the data in the formula come from.
#' @param ref_group Optional character vector (of length 1) naming the
#'   reference group to be plotted on the x-axis. Defaults to the highest
#'   scoring group.
#' @param qtiles The percentiles to split the data by and calculate effect 
#' sizes. Essentially, this is the binning argument. Defaults to 
#' \code{seq(0, 1, .33)}, which splits the distribution into thirds (lower,
#' middle, upper). Any sequence is valid, but it is recommended the bins be
#' even. For example \code{seq(0, 1, .1)} would split the distributions into
#' deciles.
#' @export
#' @examples
#' 
#' # Compute effect sizes (Cohen's d) by default quantiles
#' qtile_es(reading ~ condition, star)
#' 
#' # Compute Cohen's d by quintile
#' qtile_es(reading ~ condition, 
#' 		star, 
#' 		qtiles = seq(0, 1, .2))
#' 
#' # Report effect sizes only relative to regular-sized classrooms
#' qtile_es(reading ~ condition, 
#' 		star, 
#' 		ref_group = "reg",
#' 		qtiles = seq(0, 1, .2))


qtile_es <- function(formula, data, ref_group = NULL, 
	qtiles = seq(0, 1, .33)) {
	if(is.null(ref_group)) {
		splt <- parse_form(formula, data)
		ref_group <- names(
						which.max(
							vapply(splt, mean, na.rm = TRUE, numeric(1))
							)
						)
	}

	means <- qtile_mean_diffs(formula, data, qtiles)
	means <- means[means$ref_group == ref_group, ]

	sds <- pooled_sd(formula, data)
	names(sds)[3] <- "pooled_sd"

	es <- merge(means, sds, by = c("ref_group", "foc_group"), all.x = TRUE)
	es$es <- es$estimate / es$pooled_sd
	es$midpoint <- (es$low_qtile + es$high_qtile) / 2

	ns <- qtile_n(formula, data, qtiles)
	es <- merge(es, ns, 
					by.x = c("ref_group", "low_qtile", "high_qtile"),
					by.y = c("group", "low_qtile", "high_qtile"),
					all.x = TRUE)
	names(es)[ncol(es)] <- "ref_group_n"
	es <- merge(es, ns, 
					by.x = c("foc_group", "low_qtile", "high_qtile"),
					by.y = c("group", "low_qtile", "high_qtile"),
					all.x = TRUE)
	names(es)[ncol(es)] <- "foc_group_n"


	es$se <- se_es(es$ref_group_n, es$foc_group_n, es$es)


es[order(es$midpoint), c(4, 1:3, 8, 7, 11)]
}



#' Quantile-binned effect size plot
#' 
#' Plots the effect size between two groups by matched (binned) quantiles 
#' (i.e., the results from \link{qtile_es}), with the matched
#' quantiles plotted along the x-axis and the effect size plotted along the 
#' y-axis. The intent is to examine how (if) the magnitude of the effect size
#' varies at different points of the distributions.
#' 
#' @param formula  A formula of the type \code{out ~ group} where \code{out} is
#'   the outcome variable and \code{group} is the grouping variable. Note the
#'   grouping variable must only include only two groups.
#' @param data The data frame that the data in the formula come from.
#' @param ref_group Optional character vector (of length 1) naming the
#'   reference group to be plotted on the x-axis. Defaults to the highest
#'   scoring group.
#' @param qtiles The quantile bins to split the data by and calculate effect 
#' sizes. This argument is passed directly to \link{qtile_es}. 
#' Essentially, this is the binning argument. Defaults to \code{seq(0, 1, .33)}
#' which splits the distribution into thirds (lower, middle, upper). Any 
#' sequence is valid, but it is recommended the bins be even. For example
#' \code{seq(0, 1, .1)} would split the distributions into deciles.
#' @param se Logical. Should the standard errors around the effect size point
#' estimates be displayed? Defaults to \code{TRUE}, with the uncertainty 
#' displayed with shading. 
#' @param shade_col Color of the standard error shading, if \code{se == TRUE}.
#' Defaults to the same color as the lines.
#' @param shade_alpha Transparency level of the standard error shading.
#' Defaults to 0.3.
#' @param annotate Logical. Defaults to \code{FALSE}. When \code{TRUE} and 
#' \code{legend == "side"} the plot is rendered such that additional
#' annotations can be made on the plot using low level base plotting functions
#' (e.g., \link[graphics]{arrows}). However, if set to \code{TRUE}, 
#' \link[grDevices]{dev.off} must be called before a new plot is rendered 
#' (i.e., close the current plotting window). Otherwise the plot will be
#' attempted to be rendered in the region designated for the legend). Argument
#' is ignored when \code{legend != "side"}.
#' @param refline Logical. Defaults to \code{TRUE}. Should a diagonal
#' reference line, representing the point of equal probabilities, be plotted?
#' @param refline_col Color of the reference line. Defaults to \code{"gray"}.
#' @param refline_lty Line type of the reference line. Defaults to \code{2}.
#' @param refline_lwd Line width of the reference line. Defaults to \code{2}.
#' @param rects Logical. Should semi-transparent rectangles be plotted in the 
#' background to show the binning? Defaults to \code{TRUE}.
#' @param rect_colors Color of rectangles to be plotted in the background, if
#' \code{rects == TRUE}. Defaults to alternating gray and transparent. 
#' Currently not alterable when \code{theme == "dark"}, in which case the rects
#' alternate a semi-transparent white and transparent.
#' @param lines Logical. Should the points between effect sizes across 
#' \code{qtiles} be connected via a line? Defaults to \code{TRUE}.
#' @param points Logical. Should points be plotted for each \code{qtiles} be 
#' plotted? Defaults to \code{TRUE}.
#' @param legend The type of legend to be displayed, with possible values 
#' \code{"base"}, \code{"side"}, or \code{"none"}. Defaults to \code{"side"}, 
#' when there are more than two groups and \code{"none"} when only comparing
#' two groups. If the option \code{"side"} is used the plot is split into two
#' plots, via \link[graphics]{layout}, with the legend displayed in the second 
#' plot. This scales better than the base legend (i.e., manually manipulating
#' the size of the plot after it is rendered), but is not compatible with 
#' multi-panel plotting (e.g., \code{par(mfrow = c(2, 2))} for a 2 by 2 plot).
#' When producing multi-panel plots, use \code{"none"} or \code{"base"}, the
#' latter of which produces the legend with the base \link[graphics]{legend}
#' function.
#' @param theme Visual properties of the plot. There are currently only two
#' themes implemented - a standard plot and a dark theme. If \code{NULL} 
#' (default), the theme will be produced with a standard white background. If
#' \code{"dark"}, a dark gray background will be used with white text and axes.
#' @param ... Additional arguments passed to \link[graphics]{plot}. Note that
#' it is best to use the full argument rather than partial matching, given the
#' method used to call the plot. While some partial matching is supported 
#' (e.g., \code{m} for \code{main}, it is generally safest to supply the full
#' argument).
#' @importFrom graphics par layout axis rect points abline lines
#' @importFrom grDevices rgb adjustcolor
#' @export
#' @examples
#' 
#' # Default binned effect size plot
#' binned_plot(math ~ condition, star)
#' 
#' # Change the reference group to regular sized classrooms
#' binned_plot(math ~ condition, 
#' 		star,
#' 		ref_group = "reg")
#' 
#' # Change binning to deciles
#' binned_plot(math ~ condition, 
#' 		star,
#' 		ref_group = "reg",
#' 		qtiles = seq(0, 1, .1))
#' 
#' # Suppress the standard error shading
#' binned_plot(math ~ condition, 
#' 		star,
#' 		se = FALSE)
#' 
#' # Change to dark theme
#' binned_plot(math ~ condition, 
#' 		star,
#' 		theme = "dark")

binned_plot <- function(formula, data, ref_group = NULL,
	qtiles = seq(0, 1, .3333), se = TRUE, shade_col = NULL,
	shade_alpha = 0.3, annotate = FALSE, refline = TRUE, refline_col = "black",
	refline_lty = 2, refline_lwd = 2, rects = TRUE, 
	rect_colors = c(rgb(.2, .2, .2, .1), rgb(0.2, 0.2, 0.2, 0)), lines = TRUE,
	points = TRUE, legend = NULL, theme = NULL, ...) {

	args <- as.list(match.call())
	
	if(!is.null(theme)) {
		if(theme == "dark") {
			op <- par(bg = "gray21", 
					  col.axis = "white", 
					  col.lab = "white",
					  col.main = "white")
		}
	}
	else {
		op <- par(bg = "transparent")	
	}
	on.exit(par(op))

	d <- qtile_es(formula, data, ref_group, qtiles) 

	if(length(unique(d$foc_group)) > 1) {
		if(is.null(legend)) legend <- "side"
	}
	if(length(unique(d$foc_group)) == 1) {
		if(is.null(legend)) legend <- "none"
	}

	if(legend == "side") {
		max_char <- max(nchar(as.character(d$foc_group)))
		wdth <- 0.9 - (max_char * 0.01)
		layout(t(c(1, 2)), widths = c(wdth, 1 - wdth))	
	}
	min_est <- min(d$es, na.rm = TRUE)
	max_est <- max(d$es, na.rm = TRUE)

	default_ylim_low <- ifelse(min_est < 0, 0.05*min_est + min_est, -0.1)
	default_ylim_high <- ifelse(max_est < 0, 0.1, 0.05*max_est + max_est)

	p <- with(d, empty_plot(midpoint, es,
					paste0("Quantiles (ref group: ", unique(d$ref_group), ")"),
					"Effect Size",
					paste(as.character(formula)[c(2, 1, 3)], collapse = " "),
					default_xlim = c(0, 1),
					default_ylim = c(default_ylim_low, default_ylim_high),
					default_yaxt = "n",
					...))
	
	if(is.null(args$yaxt)) {
		axis(2, at = seq(round(default_ylim_low - 2), 
						 round(default_ylim_high + 2), 
						 .2), 
						 las = 2)
	}

    if(!is.null(theme)) {
		if(theme == "dark") {
			if(is.null(p$xaxt))	axis(1, col = "white")
			if(is.null(args$yaxt))  {
				axis(2, at = seq(round(default_ylim_low - 2), 
						 round(default_ylim_high + 2), 
						 .2), 
						 las = 2,
						 col = "white")
			}
			if(refline_col == "gray") refline_col <- "white"
			if(refline_lwd == 1) refline_lwd <- 2
		}
	}

	xaxes <- split(d$midpoint, d$foc_group)
	xaxes <- xaxes[-which.min(vapply(xaxes, length, numeric(1)))]
	yaxes <- split(d$es, d$foc_group)
	yaxes <- yaxes[-which.min(vapply(yaxes, length, numeric(1)))]

	if(rects) {
		rect_left <- unique(d$low_qtile)
		rect_right <- unique(d$high_qtile)

		if(is.null(theme)) {
			rect(rect_left, 
				min(d$es, na.rm = TRUE) - 1, 
				rect_right, 
				max(d$es, na.rm = TRUE) + 1, 
				col = rect_colors, 
				lwd = 0)
		}
		if(!is.null(theme)) {
			if(theme == "dark") {
				rect(rect_left, 
					min(d$es, na.rm = TRUE) - 1, 
					rect_right, 
					max(d$es, na.rm = TRUE) + 1, 
					col = c(rgb(1, 1, 1, .2), 
							rgb(0.1, 0.3, 0.4, 0)), 
					lwd = 0)
			}
		}
	}

	if(is.null(p$lwd)) p$lwd <- 2
	if(is.null(p$lty)) p$lty <- 1
	if(is.null(p$col)) p$col <- col_hue(length(xaxes))

	if(se) {
		x_shade <- split(d$midpoint, as.character(d$foc_group))
		x_shade <- lapply(x_shade, function(x) {
				x[1] <- x[1] - 0.01
				x[length(x)] <- x[length(x)] + 0.01
			return(c(x, rev(x)))
			})
		y_shade <- split(d, as.character(d$foc_group))
		y_shade <- lapply(y_shade, function(x) {
				lower <- x$es - x$se
				upper <- x$es + x$se
			return(c(lower, rev(upper)))
		})
		if(is.null(shade_col)) {
			shade_col <- adjustcolor(p$col, alpha.f = shade_alpha)
		}
		Map(polygon, x_shade, y_shade, col = shade_col, border = NA)		
	}

	if(lines) {
		Map(lines, xaxes, yaxes, col = p$col, lwd = p$lwd, lty = p$lty)	
	}
	if(points) {
		if(is.null(p$pch)) p$pch <- 21
		if(is.null(p$cex)) p$cex <- 1
		if(is.null(p$bg)) p$bg <- p$col
		
		Map(points, xaxes, yaxes, 
				col = p$col, 
				pch = p$pch,
				cex = p$cex,
				bg = p$bg)
	}
	if(refline) {
		if(is.null(theme)) {
			abline(h = 0, 
				col = refline_col, 
				lwd = refline_lwd,
				lty = refline_lty)
		}
		if(!is.null(theme)) abline(h = 0, lwd = 2, lty = 2, col = "white")
	}

	if(legend == "side") {
		create_legend(length(xaxes), names(xaxes), 
			col = p$col, 
			lwd = p$lwd, 
			lty = p$lty,
			left_mar = max_char * .35)
	}
	if(legend == "base") {
		if(is.null(theme)) {
			create_base_legend(names(xaxes), 
				col = p$col, 
				lwd = p$lwd, 
				lty = p$lty)
		}
		if(!is.null(theme)) {
			if(theme == "dark") {
				create_base_legend(names(xaxes), 
					col = p$col, 
					lwd = p$lwd, 
					lty = p$lty,
					text.col = "white")
			}
		}
	}
	if(annotate == TRUE) {
		par(mfg = c(1, 1))
		empty_plot(d$midpoint, d$es, 
			"", 
			"",
			xlim = c(0, 1),
			ylim = c(default_ylim_low, default_ylim_high), 
			xaxt = "n", 
			yaxt = "n")
	} 
invisible(c(as.list(match.call()), p, list(op)))
}