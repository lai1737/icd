#include <Rcpp.h>
#include "local.h"
using namespace Rcpp;
// # nocov start

// [[Rcpp::export]]
int valgrindCallgrindStart(bool zerostats = false) {
  if (zerostats) {}; // no-op
#ifdef ICD_VALGRIND
  Rcout << "Starting callgrind instrumentation..." << std::endl;
  CALLGRIND_START_INSTRUMENTATION;
  if (zerostats) {
    Rcout << "Zeroing callgrind stats." << std::endl;
    CALLGRIND_ZERO_STATS;
  }
#else
  DEBUG("NOT starting Valgrind callgrind instrumentation, not linked");
#endif
  return 0;
}

// [[Rcpp::export]]
int valgrindCallgrindStop() {
#ifdef ICD_VALGRIND
  Rcout << "Stopping Valgrind callgrind instrumentation..." << std::endl;
  CALLGRIND_STOP_INSTRUMENTATION;
#else
  DEBUG("NOT stopping Valgrind callgrind instrumentation, not linked.");
#endif
  return 0;
}

// # nocov end
