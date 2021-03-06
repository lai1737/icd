
context("WHO ICD-10 children")

test_that("basic", {
  skip_missing_icd10who()
  expect_identical(
    children(as.icd10who("A01")),
    structure(c("A01", "A010", "A011", "A012", "A013", "A014"),
      class = c("icd10who", "icd10", "character"),
      icd_short_diag = TRUE
    )
  )
})

context("generate defined child codes for ICD-10-CM")

expect_icd10cm_child_is_self <- function(...) {
  for (i in list(...)) {
    eval(bquote(expect_identical(
      children(as.icd10cm(.(i))),
      as.icd10cm(as.short_diag(.(i)))
    )))
    icd10cm_kids <- children(as.icd10cm(i))
    eval(bquote(expect_is(icd10cm_kids, "icd10")))
    eval(bquote(expect_is(icd10cm_kids, "icd10cm")))
    eval(bquote(
      expect_identical(
        icd10cm_kids,
        as.icd10cm(as.short_diag(.(i)))
      )
    ))
    children(as.icd10(i)) # should not warn
  }
}

test_that("errors found in development", {
  expect_error(regexp = NA, children(as.icd10cm("C17"), defined = TRUE))
})

test_that("children of a leaf node returns itself", {
  expect_icd10cm_child_is_self(
    "O9A119", "O9A53", "S0000XA", "T3299", "P150",
    "P159", "Z9981", "Z9989", "Z950", "C7A098",
    "C7A8"
  )
  set.seed(1441)
  with_icd10cm_version(
    ver = "2016",
    code = {
      rand_icd10cm <- generate_random_short_icd10cm_bill(50)
    }
  )
  expect_icd10cm_child_is_self(rand_icd10cm)
})

test_that("zero length ICD-10-CM children", {
  expect_empty_icd10cm_kids <- function(x, has_warning = TRUE) {
    res <- if (has_warning) {
      eval(
        bquote(
          expect_warning(
            children(as.icd10cm(x), defined = TRUE)
          )
        )
      )
    } else {
      eval(
        bquote(
          expect_warning(
            children(as.icd10cm(x), defined = TRUE),
            regexp = NA
          )
        )
      )
    }
    eval(bquote(expect_equivalent(res, as.icd10cm(character(0)))))
  }
  expect_empty_icd10cm_kids("%!^#&<>?,./")
  expect_empty_icd10cm_kids("")
  expect_empty_icd10cm_kids(c("%!^#&<>?,./", ""))
  expect_empty_icd10cm_kids(c("", ""))
  expect_empty_icd10cm_kids(character(0), has_warning = FALSE)
  expect_warning(children(icd:::icd10cm(character(0)), defined = TRUE),
    icd:::icd10cm(character(0)),
    regexp = NA
  )
})

test_that("icd10cm children with one of several missing should not segfault", {
  expect_identical(
    children(as.icd10cm(c("I792", "K551"))),
    children(as.icd10cm("K551"))
  )
  expect_identical(
    children(as.icd10cm(c("I790", "I792"))),
    children(as.icd10cm(c("I790")))
  )
})

test_that("class of children same as input class", {
  expect_identical(
    class(as.icd9("666.32")),
    class(children(as.icd9("666.32")))
  )
  expect_identical(
    class(as.icd9cm("666.32")),
    class(children(as.icd9cm("666.32")))
  )
  expect_identical(
    class(as.icd10("T27.6XXD")),
    class(children(as.icd10("T27.6XXD")))
  )
  expect_identical(
    class(as.icd10cm("T27.6XXD")),
    class(children(as.icd10cm("T27.6XXD")))
  )
})
