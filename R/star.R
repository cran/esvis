#' Data from the Tennessee class size experiment 
#' 
#' These data come from the Ecdat package and represent a cross-section of
#'  data from Project STAR (Student/Teacher Achievement Ratio), where students
#'  were randomly assigned to classrooms.
#' 
#' @format A data frame with 5748 rows and 9 columns.
#'   \describe{
#'     \item{sid}{Integer. Student identifier.}
#' 	   \item{schid}{Integer. School identifier.}
#'     \item{condition}{Character. Classroom type the student was enrolled in 
#' 			(randomly assigned to).}
#' 	   \item{tch_experience}{Integer. Number of years of teaching experience
#' 			 for the teacher in the classroom in which the student was
#' 			 enrolled.}
#' 	   \item{sex}{Character. Sex of student: "girl" or "boy".}
#' 	   \item{freelunch}{Character. Eligibility of the student for free or
#' 			 reduced price lunch: "no" or "yes"}
#'     \item{race}{Character. The identified race of the student: "white",
#' 			 "black", or "other"}
#'     \item{math}{Integer. Math scale score.}
#'     \item{reading}{Integer. Reading scale score.}
#' }

"star"