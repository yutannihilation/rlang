context("trace.R")

# These tests must come first because print method includes srcrefs
test_that("tree printing only changes deliberately", {
  skip_on_os("windows")

  scoped_options(rlang_trace_format_srcrefs = TRUE)

  dir <- normalizePath(test_path(".."))
  e <- environment()

  i <- function(i) j(i)
  j <- function(i) { k(i) }
  k <- function(i) {
    NULL
    l(i)
  }
  l <- function(i) trace_back(e)
  trace <- i()

  expect_known_output(file = test_path("test-trace-print.txt"), {
    print(trace, dir = dir)
    cat("\n")
    print(trace_subset(trace, 0L), dir = dir)
  })
})

test_that("can print tree with collapsed branches", {
  skip_on_os("windows")

  # Fake eval() call does not have same signature on old R
  skip_if(getRversion() < "3.4")

  scoped_options(rlang_trace_format_srcrefs = TRUE)

  dir <- normalizePath(test_path(".."))
  e <- environment()

  f <- function() { g() }
  g <- function() { tryCatch(h(), foo = identity, bar = identity) }
  h <- function() { tryCatch(i(), baz = identity) }
  i <- function() { tryCatch(trace_back(e)) }
  trace <- eval(quote(f()))

  expect_known_trace_output(trace,
    file = test_path("test-trace-collapsed1.txt"),
    dir = dir,
    srcrefs = TRUE
  )

  # With multiple siblings
  f <- function() eval(quote(eval(quote(g()))))
  g <- function() tryCatch(eval(quote(h())), foo = identity, bar = identity)
  h <- function() trace_back(e)
  trace <- eval(quote(f()))

  expect_known_trace_output(trace,
    file = test_path("test-trace-collapsed2.txt"),
    dir = dir,
    srcrefs = TRUE
  )
})

test_that("trace_simplify_branch() extracts last branch", {
  e <- environment()
  j <- function(i) k(i)
  k <- function(i) l(i)
  l <- function(i) eval(quote(m()), parent.frame(i))
  m <- function() trace_back(e)

  x1 <- j(1)
  expect_trace_length(x1, 6)
  expect_trace_length(trace_simplify_branch(x1), 3)

  x2 <- j(2)
  expect_trace_length(x2, 6)
  expect_trace_length(trace_simplify_branch(x2), 2)

  x3 <- j(3)
  expect_trace_length(x2, 6)
  expect_trace_length(trace_simplify_branch(x3), 1)
})

test_that("integerish indices are allowed", {
  trace <- trace_back()
  expect_identical(trace_subset(trace, 0), trace_subset(trace, 0L))
})

test_that("cli_branch() handles edge case", {
  e <- environment()
  f <- function() trace_back(e)
  trace <- f()

  call <- paste0(" ", cli_style$h, "f()")
  tree <- trace_as_tree(trace, srcrefs = FALSE)
  expect_identical(cli_branch(tree$call[-1]), call)
})

test_that("trace formatting picks up `rlang_trace_format_srcrefs`", {
  e <- environment()
  f <- function() trace_back(e)
  trace <- f()

  with_options(
    rlang_trace_format_srcrefs = FALSE,
    expect_false(any(grepl("testthat", format(trace))))
  )
  with_options(
    rlang_trace_format_srcrefs = TRUE,
    expect_true(any(!!grepl("test-trace\\.R", format(trace))))
  )
})

test_that("trace picks up option `rlang_trace_top_env` for trimming trace", {
  e <- current_env()
  f1 <- function() trace_back()
  f2 <- function() trace_back(e)
  with_options(rlang_trace_top_env = current_env(),
    expect_identical(trace_length(f1()), trace_length(f2()))
  )
})

test_that("collapsed formatting doesn't collapse single frame siblings", {
  e <- current_env()
  f <- function() eval_bare(quote(g()))
  g <- function() trace_back(e)
  trace <- f()

  full <- capture.output(print(trace, simplify = "none", srcrefs = FALSE))[[3]]
  full <- substr(full, 5, nchar(full))

  collapsed <- capture.output(print(trace, simplify = "collapse", srcrefs = FALSE))[[3]]
  collapsed <- substr(collapsed, 5, nchar(collapsed))

  expect_identical(full, "eval_bare(quote(g()))")
  expect_identical(collapsed, "[ eval_bare(...) ]")
})

test_that("recursive frames are rewired to the global env", {
  skip_on_os("windows")

  dir <- normalizePath(test_path(".."))
  e <- environment()

  f <- function() g()
  g <- function() trace_back(e)
  trace <- eval_tidy(quo(f()))

  expect_known_trace_output(trace, file = "test-trace-recursive.txt")
})

test_that("long backtrace branches are truncated", {
  skip_on_os("windows")

  e <- current_env()
  f <- function(n) {
    if (n) {
      return(f(n - 1))
    }
    trace_back(e)
  }
  trace <- f(10)

  expect_known_output(file = test_path("test-trace-truncate-backtrace-branch.txt"), {
    cat("Full:\n")
    print(trace, simplify = "branch", srcrefs = FALSE)
    cat("\n5 frames:\n")
    print(trace, simplify = "branch", max_frames = 5, srcrefs = FALSE)
    cat("\n2 frames:\n")
    print(trace, simplify = "branch", max_frames = 2, srcrefs = FALSE)
    cat("\n1 frame:\n")
    print(trace, simplify = "branch", max_frames = 1, srcrefs = FALSE)
  })

  expect_error(print(trace, simplify = "none", max_frames = 5), "currently only supported with")
  expect_error(print(trace, simplify = "collapse", max_frames = 5), "currently only supported with")
})

test_that("eval() frames are collapsed", {
  skip_on_os("windows")

  # Fake eval() call does not have same signature on old R
  skip_if(getRversion() < "3.4")

  e <- current_env()
  f <- function() base::eval(quote(g()))
  g <- function() eval(quote(trace_back(e)))
  trace <- f()

  expect_known_trace_output(trace, file = "test-trace-collapse-eval.txt")

  f <- function() base::evalq(g())
  g <- function() evalq(trace_back(e))
  trace <- f()

  expect_known_trace_output(trace, file = "test-trace-collapse-evalq.txt")
})

test_that("%>% frames are collapsed", {
  skip_on_os("windows")
  skip_if_not_installed("magrittr")

  # Fake eval() call does not have same signature on old R
  skip_if(getRversion() < "3.4")

  `%>%` <- magrittr::`%>%`

  e <- current_env()
  f <- function(x, ...) x
  g <- function(x, ...) x
  h <- function(x, ...) trace_back(e)

  trace <- NULL %>% f() %>% g(1, 2) %>% h(3, ., 4)
  expect_known_trace_output(trace, "test-trace-collapse-magrittr.txt")

  trace <- f(NULL) %>% g(list(.)) %>% h(3, ., list(.))
  expect_known_trace_output(trace, "test-trace-collapse-magrittr2.txt")

  trace <- f(g(NULL %>% f()) %>% h())
  expect_known_trace_output(trace, "test-trace-collapse-magrittr3.txt")
})

test_that("children of collapsed %>% frames have correct parent", {
  skip_on_os("windows")
  skip_if_not_installed("magrittr")

  # Fake eval() call does not have same signature on old R
  skip_if(getRversion() < "3.4")

  `%>%` <- magrittr::`%>%`

  e <- current_env()
  F <- function(x, ...) x
  G <- function(x, ...) x
  H <- function(x) f()
  f <- function() h()
  h <- function() trace_back(e)

  trace <- NA %>% F() %>% G() %>% H()
  expect_known_trace_output(trace, "test-trace-collapse-magrittr-children.txt")
})

test_that("children of collapsed frames are rechained to correct parent", {
  skip_on_os("windows")

  # Fake eval() call does not have same signature on old R
  skip_if(getRversion() < "3.4")

  e <- current_env()
  f <- function() eval(quote(g()), env())
  g <- function() trace_back(e)
  trace <- f()

  expect_known_output(file = test_path("test-trace-collapse-children.txt"), {
    cat("Full:\n")
    print(trace, simplify = "none", srcrefs = FALSE)
    cat("\nCollapsed:\n")
    print(trace, simplify = "collapse", srcrefs = FALSE)
    cat("\nBranch:\n")
    print(trace, simplify = "branch", srcrefs = FALSE)
  })
})

test_that("pipe_collect_calls() collects calls", {
  exprs2 <- function(...) unname(exprs(...))

  call <- quote(a(A %>% B) %>% b)
  out <- pipe_collect_calls(call)
  expect_identical(out$calls, exprs2(a(A %>% B), b(.)))
  expect_true(out$leading)

  call <- quote(a %>% b %>% c)
  out <- pipe_collect_calls(call)
  expect_identical(out$calls, exprs2(b(.), c(.)))
  expect_false(out$leading)

  call <- quote(a() %>% b %>% c)
  out <- pipe_collect_calls(call)
  expect_identical(out$calls, exprs2(a(), b(.), c(.)))
  expect_true(out$leading)
})

test_that("combinations of incomplete and leading pipes collapse properly", {
  skip_on_os("windows")
  skip_if_not_installed("magrittr")

  # Fake eval() call does not have same signature on old R
  skip_if(getRversion() < "3.4")

  `%>%` <- magrittr::`%>%`

  e <- current_env()
  F <- function(x, ...) x
  T <- function(x) trace_back(e)

  trace <- NA %>% F() %>% T() %>% F() %>% F()
  expect_known_trace_output(trace, "test-trace-collapse-magrittr-incomplete.txt")

  trace <- T(NA) %>% F()
  expect_known_trace_output(trace, "test-trace-collapse-magrittr-incomplete-leading1.txt")

  trace <- F(NA) %>% F() %>% T() %>% F() %>% F()
  expect_known_trace_output(trace, "test-trace-collapse-magrittr-incomplete-leading2.txt")

  trace <- NA %>% T()
  expect_known_trace_output(trace, "test-trace-collapse-magrittr-complete1.txt")

  trace <- NA %>% F() %>% T()
  expect_known_trace_output(trace, "test-trace-collapse-magrittr-complete2.txt")

  trace <- F(NA) %>% T()
  expect_known_trace_output(trace, "test-trace-collapse-magrittr-complete-leading1.txt")

  trace <- F(NA) %>% F() %>%  T()
  expect_known_trace_output(trace, "test-trace-collapse-magrittr-complete-leading2.txt")
})

test_that("calls before and after pipe are preserved", {
  skip_on_os("windows")
  skip_if_not_installed("magrittr")

  # Fake eval() call does not have same signature on old R
  skip_if(getRversion() < "3.4")

  `%>%` <- magrittr::`%>%`

  e <- current_env()
  F <- function(x, ...) x
  T <- function(x) trace_back(e)
  C <- function(x) f()
  f <- function() trace_back(e)

  trace <- F(NA %>% T())
  expect_known_trace_output(trace, "test-trace-collapse-magrittr-before-after1.txt")

  trace <- NA %>% C()
  expect_known_trace_output(trace, "test-trace-collapse-magrittr-before-after2.txt")

  trace <- F(NA %>% C())
  expect_known_trace_output(trace, "test-trace-collapse-magrittr-before-after3.txt")
})

test_that("always keep very first frame as part of backtrace branch", {
  skip_on_os("windows")

  # Fake eval() call does not have same signature on old R
  skip_if(getRversion() < "3.4")

  e <- current_env()

  gen <- function(x) UseMethod("gen")
  gen.default <- function(x) trace_back(e)

  trace <- gen()
  expect_known_trace_output(trace, "test-trace-backtrace-branch-first-frame.txt")
})

test_that("can take the str() of a trace (#615)", {
  e <- current_env()
  f <- function(n) if (n < 10) f(n - 1) else trace_back(e)
  expect_output(expect_no_error(str(f(10))))
})
