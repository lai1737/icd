#' Calculate Charlson Comorbidity Index (Charlson Score)
#'
#' Charlson score is calculated in the basis of the Quan revision of Deyo's
#' ICD-9 mapping. (Peptic ulcer disease no longer warrants a point.) Quan
#' published an updated set of scores, but it seems most people use the original
#' scores for easier comparison between studies, even though Quan's were more
#' predictive.
#' @details When used, hierarchy is applied per Quan, \dQuote{The following
#'   comorbid conditions were mutually exclusive: diabetes with chronic
#'   complications and diabetes without chronic complications; mild liver
#'   disease and moderate or severe liver disease; and any malignancy and
#'   metastatic solid tumor.} The Quan scoring weights come from the 2011 paper
#'   (dx.doi.org/10.1093/aje/kwq433). The comorbidity weights were recalculated
#'   using updated discharge data, and some changes, such as Myocardial
#'   Infarction decreasing from 1 to 0, may reflect improved outcomes due to
#'   advances in treatment since the original weights were determined in 1984.
#' @param x data frame containing a column of visit or patient identifiers, and
#'   a column of ICD-9 codes. It may have other columns which will be ignored.
#'   By default, the first column is the patient identifier and is not counted.
#'   If \code{visit_name} is not specified, the first column is used.
#' @template visit_name
#' @template scoring-system
#' @param return_df single logical value, if \code{TRUE}, a two column data
#'   frame will be returned, with the first column named as in input data frame
#'   (i.e., \code{visit_name}), containing all the visits, and the second column
#'   containing the Charlson Comorbidity Index.
#' @param stringsAsFactors single logical, passed on when constructing
#'   data.frame if \code{return_df} is \code{TRUE}. If the input data frame
#'   \code{x} has a factor for the \code{visit_name}, this is not changed, but a
#'   non-factor \code{visit_name} may be converted or not converted according to
#'   your system default or this setting.
#' @param ... further arguments to pass on to \code{icd9_comorbid_quan_deyo},
#'   e.g. \code{name}
#' @examples
#' mydf <- data.frame(
#'   visit_name = c("a", "b", "c"),
#'   icd9 = c("441", "412.93", "042")
#' )
#' charlson(mydf)
#' cmb <- icd9_comorbid_quan_deyo(mydf)
#' cmb
#' # can specify short_code directly instead of guessing
#' charlson(mydf, short_code = FALSE, return_df = TRUE)
#' charlson_from_comorbid(cmb)
#' @export
charlson <- function(x, visit_name = NULL,
                     scoring_system = c("original", "charlson", "quan"),
                     return_df = FALSE,
                     stringsAsFactors = getOption("stringsAsFactors"), # nolint
                     ...) {
  UseMethod("charlson")
}

#' @describeIn charlson Charlson scores from data frame of visits and ICD-9
#'   codes. ICD-10 Charlson can be calculated simply by getting the Charlson
#'   (e.g. Quan Deyo) comorbidities, then calling
#'   \code{charlson_from_comorbid}.
#' @export
charlson.data.frame <- function(x,
                                visit_name = NULL,
                                scoring_system = c("original", "charlson", "quan"),
                                return_df = FALSE,
                                stringsAsFactors = getOption("stringsAsFactors"), # nolint
                                ...) {
  stopifnot(is.data.frame(x), ncol(x) >= 2, !is.null(colnames(x)))
  stopifnot(is.null(visit_name) ||
    (is.character(visit_name) && length(visit_name) == 1L))
  stopifnot(is.null(visit_name) ||
    (is.character(visit_name) && length(visit_name) == 1L))
  assert_flag(return_df)
  assert_flag(stringsAsFactors) # nolint
  visit_name <- get_visit_name(x, visit_name)
  res <- charlson_from_comorbid(
    comorbid_quan_deyo(x,
      visit_name = visit_name,
      hierarchy = TRUE,
      return_df = TRUE, ...
    ),
    visit_name = visit_name,
    hierarchy = FALSE,
    scoring_system = scoring_system
  )
  if (!return_df) return(res)
  out <- cbind(names(res),
    data.frame("Charlson" = unname(res)),
    stringsAsFactors = stringsAsFactors
  ) # nolint
  names(out)[1] <- visit_name
  out
}

#' Calculate Charlson scores from precomputed Charlson comorbidities
#'
#' Calculate Charlson scores from precomputed Charlson comorbidities, instead
#' of directly from the ICD codes. This is useful if the comorbidity calculation
#' is time consuming. Commonly, both the Charlson comorbidities and the Charlson
#' scores will be calculated, and this function provides just that second step.
#' @param x data.frame or matrix, typically the output of a comorbidity
#'   calculation which uses the Charlson categories, e.g.
#'   \code{comorbid_quan_deyo}
#' @template visit_name
#' @param hierarchy single logical value, default is \code{FALSE}. If
#'   \code{TRUE}, will drop \code{DM} if \code{DMcx} is present, etc.
#' @template scoring-system
#' @export
charlson_from_comorbid <- function(x,
                                   visit_name = NULL,
                                   hierarchy = FALSE,
                                   scoring_system = c("original", "charlson", "quan")) {
  stopifnot(is.data.frame(x) || is.matrix(x))
  stopifnot(nrow(x) > 0, ncol(x) >= 2)
  stopifnot(!is.null(colnames(x)))
  stopifnot(ncol(x) - is.data.frame(x) == 17)
  if (match.arg(scoring_system) == "quan") {
    weights <- c(
      0, 2, 0, 0, 2, 1, 1, 0, 2, 0,
      1, 2, 1, 2, 4, 6, 4
    )
  } else {
    weights <- c(
      1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
      2, 2, 2, 2, 3, 6, 6
    )
  }
  if (hierarchy) {
    x[, "DM"] <- x[, "DM"] & !x[, "DMcx"]
    x[, "LiverMild"] <- x[, "LiverMild"] & !x[, "LiverSevere"]
    x[, "Cancer"] <- x[, "Cancer"] & !x[, "Mets"]
  } else {
    stopifnot(!any(x[, "DM"] & x[, "DMcx"]))
    stopifnot(!any(x[, "LiverMild"] & x[, "LiverSevere"]))
    stopifnot(!any(x[, "Cancer"] & x[, "Mets"]))
  }
  if (is.data.frame(x)) {
    visit_name <- get_visit_name(x, visit_name)
    visit_row_names <- x[[visit_name]]
    x <- as.matrix(x[, names(x) %nin% visit_name])
    rownames(x) <- visit_row_names
  }
  rowSums(t(t(x) * weights))
}

#' Count ICD codes or comorbidities for each patient
#'
#' \code{count_codes} takes a data frame with a column for \code{visit_name}
#' and another for ICD-9 code, and returns the number of distinct codes for each
#' patient.
#'
#' The \code{visit_name} field is typically the first column. If there is no
#' column called \code{visit_name} and \code{visit_name} is not specified, the
#' first column is used.
#' @param x data frame with one row per patient, and a true/false or 1/0 flag
#'   for each column. By default, the first column is the patient identifier and
#'   is not counted. If \code{visit_name} is not specified, the first column is
#'   used.
#' @template visit_name
#' @param return_df single logical, if \code{TRUE}, return the result as a data
#'   frame with the first column being the \code{visit_name}, and the second
#'   being the count. If \code{visit_name} was a factor or named differently in
#'   the input, this is preserved.
#' @return vector of the count of comorbidities for each patient. This is
#'   sometimes used as a metric of comorbidity load, instead of, or in addition
#'   to metrics like the Charlson Comorbidity Index (aka Charlson Score)
#' @examples
#' mydf <- data.frame(
#'   visit_name = c("r", "r", "s"),
#'   icd9 = c("441", "412.93", "042")
#' )
#' count_codes(mydf, return_df = TRUE)
#' count_codes(mydf)
#' 
#' cmb <- icd9_comorbid_quan_deyo(mydf, short_code = FALSE, return_df = TRUE)
#' count_comorbid(cmb)
#' 
#' wide <- data.frame(
#'   visit_name = c("r", "s", "t"),
#'   icd9_1 = c("0011", "441", "456"),
#'   icd9_2 = c(NA, "442", NA),
#'   icd9_3 = c(NA, NA, "510")
#' )
#' count_codes_wide(wide)
#' # or:
#' \dontrun{
#' library(magrittr, warn.conflicts = FALSE)
#' wide %>% wide_to_long() %>% count_codes()
#' }
#' @export
count_codes <- function(x,
                        visit_name = get_visit_name(x),
                        return_df = FALSE) {
  stopifnot(is.data.frame(x), ncol(x) >= 2, !is.null(colnames(x)))
  assert_string(visit_name)
  assert_flag(return_df)
  res <- stats::aggregate(x[names(x) %nin% visit_name],
    by = x[visit_name],
    FUN = length
  )
  names(res)[names(res) %nin% visit_name] <- "icd_count"
  if (return_df) {
    res
  } else {
    res[["icd_count"]]
  }
}

#' Count number of comorbidities per patient
#'
#' \code{count_comorbid} differs from the other counting functions in that
#' it counts \emph{comorbidities}, not individual diagnoses. It accepts any
#' \code{data.frame} with either logical or binary contents, with a single
#' column for visit_name. No checks are made to see whether visit_name is
#' duplicated.
#'
#' @param x data frame with one row per patient, and a true/false or 1/0 flag
#'   for each column. By default, the first column is the patient identifier and
#'   is not counted. If \code{visit_name} is not specified, the first column is
#'   used.
#' @template visit_name
#' @template return_df
#' @export
count_comorbid <- function(x,
                           visit_name = get_visit_name(x),
                           return_df = FALSE) {
  assert_string(visit_name)
  assert_flag(return_df)
  stopifnot(is.data.frame(x) || is.matrix(x))
  res <- apply(x[, names(x) %nin% visit_name],
    MARGIN = 1,
    FUN = sum
  )
  names(res) <- x[[visit_name]]
  if (return_df) {
    cbind(x[visit_name], "icd_count" = res)
  } else {
    res
  }
}

#' Count ICD codes given in wide format
#'
#' For \code{count_codes}, it is assumed that all the columns apart from
#' \code{visit_name} represent actual or possible ICD-9 codes. Duplicate
#' \code{visit_name}s are repeated as given and aggregated.
#' @param x \code{data.frame} with one row per patient, hospital visit,
#'   encounter, etc., and multiple columns containing any ICD codes attributed
#'   to that encounter or patient. i.e. data frame with ICD codes in wide
#'   format.
#' @template visit_name
#' @template return_df
#' @param aggr single logical, default is \code{FALSE}. If \code{TRUE}, the
#'   length (or rows) of the output will no longer match the input, but
#'   duplicate \code{visit_name}s will be counted together.
#' @importFrom stats aggregate
#' @export
count_codes_wide <- function(x,
                             visit_name = get_visit_name(x),
                             return_df = FALSE,
                             aggr = FALSE) {
  stopifnot(is.data.frame(x))
  assert_string(visit_name)
  assert_flag(return_df)
  assert_flag(aggr)

  res <- apply(x[names(x) %nin% visit_name], 1, function(x) sum(!is.na(x)))
  names(res) <- x[[visit_name]]
  if (!aggr) {
    if (return_df) {
      return(cbind(x[visit_name], "count" = res))
    } else {
      return(res)
    }
  }
  rdf <- cbind(x[visit_name], "count" = res)
  rdfagg <- aggregate(rdf["count"], by = rdf[visit_name], FUN = sum)
  if (return_df) return(rdfagg)
  vec <- rdfagg[["count"]]
  names(vec) <- rdfagg[[visit_name]]
  vec
}

#' Calculate van Walraven Elixhauser Score
#'
#' van Walraven Elixhauser score is calculated from the Quan revision of
#' Elixhauser's ICD-9 mapping. This function allows for the hierarchical
#' exclusion of less severe versions of comorbidities when their more severe
#' version is also present via the \code{hierarchy} argument. For the Elixhauser
#' comorbidities, this is diabetes v. complex diabetes and solid tumor v.
#' metastatic tumor
#' @param x data frame containing a column of visit or patient identifiers, and
#'   a column of ICD-9 codes. It may have other columns which will be ignored.
#'   By default, the first column is the patient identifier and is not counted.
#'   If \code{visit_name} is not specified, the first column is used.
#' @template visit_name
#' @param return_df single logical value, if \code{TRUE}, a two column data
#'   frame will be returned, with the first column named as in input data frame
#'   (i.e., \code{visit_name}), containing all the visits, and the second column
#'   containing the Charlson Comorbidity Index.
#' @template stringsAsFactors
#' @template dotdotdot
#' @examples
#' mydf <- data.frame(
#'   visit_name = c("a", "b", "c"),
#'   icd9 = c("412.93", "441", "042")
#' )
#' van_walraven(mydf)
#' # or calculate comorbodities first:
#' cmb <- icd9_comorbid_quan_elix(mydf, short_code = FALSE, hierarchy = TRUE)
#' vwr <- van_walraven_from_comorbid(cmb)
#' stopifnot(identical(van_walraven(mydf), vwr))
#' 
#' # alternatively return as data frame in 'tidy' format
#' van_walraven(mydf, return_df = TRUE)
#' @author wmurphyrd
#' @references van Walraven C, Austin PC, Jennings A, Quan H, Forster AJ. A
#'   Modification to the Elixhauser Comorbidity Measures Into a Point System for
#'   Hospital Death Using Administrative Data. Med Care. 2009; 47(6):626-633.
#'   \url{http://www.ncbi.nlm.nih.gov/pubmed/19433995}
#' @export
van_walraven <- function(x,
                         visit_name = NULL,
                         return_df = FALSE,
                         stringsAsFactors = getOption("stringsAsFactors"), # nolint
                         ...) {
  UseMethod("van_walraven")
}

#' @describeIn van_walraven van Walraven scores from data frame of visits
#'   and ICD-9 codes
#' @export
van_walraven.data.frame <- function(x,
                                    visit_name = NULL,
                                    return_df = FALSE,
                                    stringsAsFactors = getOption("stringsAsFactors"), # nolint
                                    ...) {
  stopifnot(is.data.frame(x), ncol(x) >= 2, !is.null(colnames(x)))
  stopifnot(is.null(visit_name) ||
    (is.character(visit_name) && length(visit_name) == 1L))
  assert_flag(return_df)
  assert_flag(stringsAsFactors) # nolint
  visit_name <- get_visit_name(x, visit_name)
  tmp <- icd9_comorbid_quan_elix(x,
    visit_name,
    hierarchy = TRUE,
    return_df = TRUE, ...
  )
  res <- van_walraven_from_comorbid(tmp,
    visit_name = visit_name,
    hierarchy = FALSE
  )
  if (!return_df) return(res)
  out <- cbind(names(res),
    data.frame("vanWalraven" = unname(res)),
    stringsAsFactors = stringsAsFactors
  ) # nolint
  names(out)[1] <- visit_name
  out
}

#' @rdname van_walraven
#' @param hierarchy single logical value that defaults to \code{TRUE}, in
#'   which case the hierarchy defined for the mapping is applied. E.g. in
#'   Elixhauser, you can't have uncomplicated and complicated diabetes both
#'   flagged.
#' @export
van_walraven_from_comorbid <- function(x,
                                       visit_name = NULL,
                                       hierarchy = FALSE) {
  stopifnot(is.data.frame(x) || is.matrix(x))
  stopifnot(is.null(visit_name) ||
    (is.character(visit_name) && length(visit_name) == 1L))
  assert_flag(hierarchy)
  stopifnot(ncol(x) - is.data.frame(x) == 30)
  weights <- c(
    7, 5, -1, 4, 2, 0, 7, 6, 3, 0, 0, 0, 5, 11, 0, 0,
    9, 12, 4, 0, 3, -4, 6, 5, -2, -2, 0, -7, 0, -3
  )
  if (hierarchy) {
    x[, "DM"] <- x[, "DM"] & !x[, "DMcx"]
    x[, "Tumor"] <- x[, "Tumor"] & !x[, "Mets"]
  } else {
    stopifnot(!any(x[, "DM"] & x[, "DMcx"]))
    stopifnot(!any(x[, "Tumor"] & x[, "Mets"]))
  }
  if (is.data.frame(x)) {
    visit_name <- get_visit_name(x, visit_name)
    visit_row_names <- x[[visit_name]]
    x <- as.matrix(x[, names(x) %nin% visit_name])
    rownames(x) <- visit_row_names
  }
  rowSums(t(t(x) * weights))
}
