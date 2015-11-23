# Copyright (C) 2014 - 2015  Jack O. Wasey
#
# This file is part of icd9.
#
# icd9 is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# icd9 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with icd9. If not, see <http:#www.gnu.org/licenses/>.

# icd9Children separate from C++ docs so that I can guess isShort
#' @name icd9Children
#' @title Expand ICD-9 codes to all possible sub-codes
#' @template icd9-any
#' @template icd9-short
#' @template icd9-decimal
#' @template isShort
#' @template onlyReal
#' @template onlyBillable
#' @keywords manip
#' @family ICD-9 ranges
#' @examples
#' library(magrittr)
#' icd9ChildrenShort("10201", FALSE) # no children other than self
#' icd9Children("0032", FALSE) # guess it was a short, not decimal code
#' icd9ChildrenShort("10201", TRUE) # empty because 102.01 is not meaningful
#' icd9ChildrenShort("003", TRUE) %>% icd9ExplainShort(doCondense = FALSE)
#' icd9ChildrenDecimal("100.0")
#' icd9ChildrenDecimal("100.00")
#' icd9ChildrenDecimal("2.34")
#' @export
icd_children <- function(icd, ...)
  UseMethod("icd_children")

#' @describeIn icd_children Get children of ICD-9 codes
icd_children.icd9 <- function(icd9, short = icd_guess_short(icd9),
                         real = TRUE, billable = FALSE) {
  assertFactorOrCharacter(icd9)
  assertFlag(short)
  assertFlag(real)

  if (short)
    res <- .Call("icd9_icd9ChildrenShortCpp", PACKAGE = get_pkg_name(), toupper(icd9), real)
  else
    res <- .Call("icd9_icd9ChildrenDecimalCpp", PACKAGE = get_pkg_name(), toupper(icd9), real)

  if (billable)
    icd9GetBillable(res, short)
  else
    res
}

utils::globalVariables("icd10cm2016")

#' real icd10 children based on 2016 ICD-10-CM list
#'
#' @keywords internal
icd_children_real <- function(x)
  UseMethod("icd_children_real")

#' @describeIn icd_children_real get the children of ICD-10 code(s)
#' @keywords internal
icd_children_real.icd10 <- function(icd, short = icd_guess_short(icd)) {

  checkmate::assertCharacter(icd)
  checkmate::assertFlag(short)

  if (inherits(icd, "icd10") && !inherits(icd, "icd10cm"))
    warning("This function primarily gives 'real' child codes for ICD-10-CM,
            which is mostly a superset of ICD-10 WHO")

  icd10Short <- stringr::str_trim(icd)

  matches_bool <- icd10Short %in% icd9::icd10cm2016[["code"]]
  # if the codes are not in the source file, we ignore, warn, drop silently?
  if (!all(matches_bool)) warning("some values did not match any ICD-10-CM codes: ",
                                  paste(icd10Short[!matches_bool], collapse = ", "))

  icd10Short <- icd10Short[matches_bool]
  matches <- match(icd10Short, icd9::icd10cm2016[["code"]])
  last_row <- nrow(icd9::icd10cm2016)

  nc <- nchar(icd9::icd10cm2016[["code"]]) # TODO: pre-compute and save in package data

  kids <- character(0)

  if (length(icd10Short) == 0 ) {
    warning("none of the provided ICD-10 codes matched the canonical list")
    return(kids)
  }

  for (i in seq_along(icd10Short)) {
    # now the children, assuming the source file is sorted logically, will be subsequent codes, until a code of the same length is found
    check_row <- matches[i] + 1
    parent_len <- nc[matches[i]]
    while (nc[check_row] > parent_len && check_row != last_row + 1)
      check_row <- check_row + 1

    kids <- c(kids, icd9::icd10cm2016[matches[i]:(check_row - 1), "code"])
  }
  kids

}

#' Generate possible children of given ICD-10 codes
#'
#' ultimately, this will have to be coding-scheme dependent, e.g. ICD-10-CM for
#' USA, vs various national or international schemes
#'
#' @details This is inefficient due to the large number of combinations of
#'   possible codes. I've already limited the scope to letters which appear at
#'   certain positions in ICD-10-CM 2016. Maybe best just to limit to 'real'
#'   codes, and then, when a user gives a squiffy code, e.g. a known code with
#'   an additional unknown value, we can: first account for all known codes in a
#'   list, then for unknown codes, partial match from left for known codes, and
#'   if we match more than one, then we take the longest matching known code.
#'
#'   presumption is that we start with at least a major level code. We don't
#'   extrapolate from A10 to A10-19 for example. regex pattern for ICD-10 is
#'   [[:alpha:]][[:digit:]][[:alnum]]{1,5} (not case sensitive)
#'
#'   can have x as placeholder: ignoring it will have same effect if making
#'   children
#'
#'   there are very many alphanumeric values possible in last 4 digits (26^4 =
#'   456976) however, hardly any alphas are used.
#'
#' @param icd910Short character vector of ICD-10 codes
#' @export
icd10ChildrenPossibleShort <- function(icd10Short) {
  checkmate::assertCharacter(icd10Short)

  fourth <- unlist(strsplit("0123456789ABCDEFGHIJKXZ", ""))
  fifth  <- unlist(strsplit("0123456789AXYZ", ""))
  sixth  <- unlist(strsplit("0123456789X", ""))
  seventh  <- unlist(strsplit("0123459ABCDEFGHJKMNPQRS", ""))

  minor_chars <- list(fourth, fifth, sixth, seventh)
  minor_chars <- lapply(minor_chars, append, "")

  # combining using 'outer' and 'paste'
  # as.vector(outer(fourth, fifth, paste, sep=""))

  # minimum code length is 3: i.e. [[:alpha:]][[:digit:]][[:alnum]]
  nc <- nchar(icd10Short)
  out_complete <- icd10Short[nc == 7]

  icd10Short <- icd10Short[nc >= 3 & nc < 7] # TODO: strip whitespace first if expedient
  if (length(icd10Short) == 0)
    return(out_complete)

  out <- character(0)
  for (i in icd10Short) {
    o <- i
    n <- nchar(i)
    for (j in n:6)
      o <- as.vector(outer(o, minor_chars[[j - 2]], paste, sep = ""))

    out <- c(out, o)
  }

  icd_sort.icd10(c(out_complete, out))
}

#' @rdname icd_children
#' @export
icd9Children <- function(icd9, isShort = icd_guess_short(icd9), onlyReal = TRUE, onlyBillable = FALSE) {
  .Deprecated("icd_children")
  icd_children.icd9(icd9, short = isShort, real = onlyReal, billable = onlyBillable)
}

#' @rdname icd_children
#' @export
icd9ChildrenShort <- function(icd9Short, onlyReal = TRUE, onlyBillable = FALSE) {
  .Deprecated("icd_children")
  icd_children.icd9(icd9Short, short = TRUE, real = onlyReal, billable = onlyBillable)
}

#' @rdname icd_children
#' @export
icd9ChildrenDecimal <- function(icd9Decimal, onlyReal = TRUE, onlyBillable = FALSE) {
  .Deprecated("icd_children")
  icd_children.icd9(icd9Decimal, short = FALSE, real = onlyReal, billable = onlyBillable)
}