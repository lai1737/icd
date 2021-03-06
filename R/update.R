# nocov start

#' Generate all package data
#'
#' Parses (and downloads if necessary) CDC annual revisions of ICD-9-CM to get
#' the 'billable' codes. Also parses the AHRQ, Quan/Deyo, and CMS HCC
#' comorbidity mappings from the source SAS data. Elixhauser and Quan/Elixhauser
#' mappings are generated from transcribed codes.
#' @keywords internal datagen
#' @noRd
.update_everything <- function() {
  old_opt <- options(
    icd.data.offline = FALSE,
    icd.data.verbose = TRUE
  )
  on.exit(options(old_opt), add = TRUE)
  .parse_icd9cm_leaf_year(
    year = "2014",
    save_pkg_data = TRUE
  )
  .print_options()
  .set_icd_data_dir()
  .print_options()
  .icd10cm_extract_sub_chapters(save_pkg_data = TRUE)
  .generate_sysdata()
  load(file.path("R", "sysdata.rda"))
  .generate_spelling()
  message("Parsing comorbidity mappings from SAS and text sources.
                       (Make sure lookup files are updated first.)
                       Depends on icd9cm_hierarchy being updated.")
  # ICD 9
  icd9_parse_ahrq_sas(save_pkg_data = TRUE)
  icd9_parse_quan_deyo_sas(save_pkg_data = TRUE)
  .parse_icd9cm_cc(save_pkg_data = TRUE)
  icd9_parse_ahrq_ccs(single = TRUE, save_pkg_data = TRUE)
  icd9_parse_ahrq_ccs(single = FALSE, save_pkg_data = TRUE)
  icd10_parse_ahrq_ccs(version = "2018.1", save_pkg_data = TRUE)
  icd9_generate_map_quan_elix(save_pkg_data = TRUE)
  icd9_generate_map_elix(save_pkg_data = TRUE)
  # ICD 10
  .parse_icd10cm_all(save_pkg_data = TRUE)
  icd10_parse_ahrq_sas(save_pkg_data = TRUE)
  .parse_icd10cm_cc(save_pkg_data = TRUE)
  icd10_generate_map_quan_elix(save_pkg_data = TRUE)
  icd10_generate_map_quan_deyo(save_pkg_data = TRUE)
  icd10_generate_map_elix(save_pkg_data = TRUE)
  generate_maps_pccc(save_pkg_data = TRUE)
  icd10_parse_map_ahrq_pc(save_pkg_data = TRUE)
  .parse_cc_hierarchy(save_pkg_data = TRUE)
  # icd9cm2014_leaf was formerly "icd9cm_billable[[version_number]]"
  icd9cm2014_leaf <- get_icd9cm2014_leaf()
  .save_in_data_dir(icd9cm2014_leaf)
  # TODO: deprecate and remove icd10cm2016 in icd 4.1 or 4.2
  icd10cm2016 <- .parse_icd10cm_year(2016)
  .save_in_data_dir(icd10cm2016)
  icd10cm2019 <- .parse_icd10cm_year(2019)
  .save_in_data_dir(icd10cm2019)
  icd9cm_hierarchy <- get_icd9cm2014()
  names(icd9cm_hierarchy)[names(icd9cm_hierarchy) == "leaf"] <- "billable"
  .save_in_data_dir(icd9cm_hierarchy)
  #.generate_vigette_index()
}

#' Generate \code{sysdata.rda}
#'
#' Generate correctly ordered look-up tables of numeric-only, V and E codes.
#' This is quick, but much too slow when it appears many times in a loop.
#' @template save_pkg_data
#' @return invisibly returns the data as a list
#' @keywords internal
#' @noRd
.generate_sysdata <- function(save_pkg_data = TRUE) {
  path <- file.path("R", "sysdata.rda")
  icd9_short_n <- icd9_generate_all_n()
  icd9_short_v <- icd9_generate_all_v()
  icd9_short_e <- icd9_generate_all_e()
  # we can either use the is_defined functions on these lists, or just grep the
  # canonical list directly to get the numeric, V and E codes.
  codes <- icd9cm_hierarchy[["code"]]
  icd9_short_n_defined <- vec_to_lookup_pair(grep("^[^VE]+", codes, perl = TRUE, value = TRUE))
  icd9_short_v_defined <- vec_to_lookup_pair(grep("^V", codes, perl = TRUE, value = TRUE))
  icd9_short_e_defined <- vec_to_lookup_pair(grep("^E", codes, perl = TRUE, value = TRUE))
  # also consider doing this in the ranging functions, even though slower, so
  # version can be chosen each time.
  icd9_short_n_leaf <- vec_to_lookup_pair(get_billable.icd10cm(
    icd9_short_n_defined$vec,
    short_code = TRUE, icd9cm_edition = "32"
  )) # nolint
  icd9_short_v_leaf <- vec_to_lookup_pair(get_billable.icd10cm(
    icd9_short_v_defined$vec,
    short_code = TRUE, icd9cm_edition = "32"
  )) # nolint
  icd9_short_e_leaf <- vec_to_lookup_pair(get_billable.icd10cm(
    icd9_short_e_defined$vec,
    short_code = TRUE, icd9cm_edition = "32"
  )) # nolint
  # minimal test here just to use variable names to avoid warnings!
  stopifnot(length(icd9_short_n$vec) == length(icd9_short_n$env))
  stopifnot(length(icd9_short_v$vec) == length(icd9_short_v$env))
  stopifnot(length(icd9_short_e$vec) == length(icd9_short_e$env))
  stopifnot(length(icd9_short_n_leaf$vec) == length(icd9_short_n_leaf$env))
  stopifnot(length(icd9_short_v_leaf$vec) == length(icd9_short_v_leaf$env))
  stopifnot(length(icd9_short_e_leaf$vec) == length(icd9_short_e_leaf$env))
  icd9_short_e
  icd9_short_n_leaf
  icd9_short_v_leaf
  icd9_short_e_leaf
  sysdata_names <- c(
    "icd9_short_n",
    "icd9_short_v",
    "icd9_short_e",
    "icd9_short_n_defined",
    "icd9_short_v_defined",
    "icd9_short_e_defined",
    "icd9_short_n_leaf",
    "icd9_short_v_leaf",
    "icd9_short_e_leaf"
  )
  # we assume we are in the root of the package directory. Save to sysdata.rda
  # because these are probably not of interest to a user and would clutter an
  # already busy namespace.
  if (save_pkg_data) {
    save(
      list = sysdata_names,
      file = path,
      compress = "xz",
      version = 2
    )
  }
  invisible(mget(sysdata_names))
}

icd9_generate_all_major_n <- function() {
  sprintf("%03d", 1:999)
}

icd9_generate_all_major_v <- function() {
  sprintf("V%02d", 1:99)
}

icd9_generate_all_major_e <- function() {
  sprintf("E%03d", 0:999)
}

icd9_generate_all_n <- function(...) {
  icd9_generate_all_(major_fun = icd9_generate_all_major_n, ...)
}

icd9_generate_all_v <- function(...) {
  icd9_generate_all_(major_fun = icd9_generate_all_major_v, ...)
}

icd9_generate_all_e <- function(...) {
  icd9_generate_all_(major_fun = icd9_generate_all_major_e, ...)
}

#' Generate lookup data for each class of ICD-9 code
#'
#' This is a little painful but the data is small enough, with huge speed gains
#' in common operations
#' @return list with two items, the first being an environment, the second being
#'   a vector. The environment has short ICD-9 codes as the names, and the
#'   sequence number as the contents. The vector contains the codes in order.
#' @keywords internal
#' @noRd
icd9_generate_all_ <- function(major_fun,
                               short_code = TRUE,
                               env = new.env(hash = TRUE, baseenv())) {
  vec <- character()
  for (i in major_fun()) {
    kids <- children.icd9(i, short_code = short_code, defined = FALSE)
    vec <- c(vec, kids)
  }
  vec_to_env_count(vec, env = env)
  invisible(list(env = env, vec = env_to_vec_flip(env)))
}

# nocov end
