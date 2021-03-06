#' Create a condition object
#'
#' These constructors make it easy to create subclassed conditions.
#' Conditions are objects that power the error system in R. They can
#' also be used for passing messages to pre-established handlers.
#'
#' `cnd()` creates objects inheriting from `condition`. Conditions
#' created with `error_cnd()`, `warning_cnd()` and `message_cnd()`
#' inherit from `error`, `warning` or `message`.
#'
#' @section Lifecycle:
#'
#' The `.type` and `.msg` arguments have been renamed to `.subclass`
#' and `message`. They are defunct as of rlang 0.3.0.
#'
#' @param .subclass The condition subclass.
#' @param ... Named data fields stored inside the condition
#'   object. These dots are evaluated with [explicit
#'   splicing][tidy-dots].
#' @param message A default message to inform the user about the
#'   condition when it is signalled.
#' @param call A call documenting what expression caused a condition
#'   to be signalled.
#' @param trace A `trace` object created by [trace_back()].
#' @param parent A parent condition object created by [abort()].
#' @seealso [cnd_signal()], [with_handlers()].
#' @export
#' @examples
#' # Create a condition inheriting from the s3 type "foo":
#' cnd <- cnd("foo")
#'
#' # Signal the condition to potential handlers. Since this is a bare
#' # condition the signal has no effect if no handlers are set up:
#' cnd_signal(cnd)
#'
#' # When a relevant handler is set up, the signal causes the handler
#' # to be called:
#' with_handlers(cnd_signal(cnd), foo = exiting(function(c) "caught!"))
#'
#' # Handlers can be thrown or executed inplace. See with_handlers()
#' # documentation for more on this.
#'
#' # Signalling an error condition aborts the current computation:
#' err <- error_cnd("foo", message = "I am an error")
#' try(cnd_signal(err))
cnd <- function(.subclass, ..., message = "", call = NULL) {
  if (missing(.subclass)) {
    abort("Bare conditions must be subclassed")
  }
  .Call(rlang_new_condition, c(.subclass, "rlang_condition"), message, call, dots_list(...))
}
#' @rdname cnd
#' @export
error_cnd <- function(.subclass = NULL,
                      ...,
                      message = "",
                      call = NULL,
                      trace = NULL,
                      parent = NULL) {
  if (!is_null(trace) && !inherits(trace, "rlang_trace")) {
    abort("`trace` must be NULL or an rlang backtrace")
  }
  if (!is_null(parent) && !inherits(parent, "condition")) {
    abort("`parent` must be NULL or a condition object")
  }
  fields <- dots_list(trace = trace, parent = parent, ...)
  .Call(rlang_new_condition, c(.subclass, "rlang_error", "error"), message, call, fields)
}
#' @rdname cnd
#' @export
warning_cnd <- function(.subclass = NULL, ..., message = "", call = NULL) {
  .Call(rlang_new_condition, c(.subclass, "warning"), message, call, dots_list(...))
}
#' @rdname cnd
#' @export
message_cnd <- function(.subclass = NULL, ..., message = "", call = NULL) {
  .Call(rlang_new_condition, c(.subclass, "message"), message, call, dots_list(...))
}

#' Is object a condition?
#' @param x An object to test.
#' @export
is_condition <- function(x) {
  inherits(x, "condition")
}

#' What type is a condition?
#'
#' Use `cnd_type()` to check what type a condition is.
#'
#' @param cnd A condition object.
#' @return A string, either `"condition"`, `"message"`, `"warning"`,
#'   `"error"` or `"interrupt"`.
#' @export
#' @examples
#' cnd_type(catch_cnd(abort("Abort!")))
#' cnd_type(catch_cnd(interrupt()))
cnd_type <- function(cnd) {
  .Call(rlang_cnd_type, cnd)
}

#' Signal a condition
#'
#' Signal a condition to handlers that have been established on the
#' stack. Conditions signalled with `cnd_signal()` are assumed to be
#' benign. Control flow can resume normally once the condition has
#' been signalled (if no handler jumped somewhere else on the
#' evaluation stack). On the other hand, `cnd_abort()` treats the
#' condition as critical and will jump out of the distressed call
#' frame (see [rst_abort()]), unless a handler can deal with the
#' condition.
#'
#' If `.critical` is `FALSE`, this function has no side effects beyond
#' calling handlers. In particular, execution will continue normally
#' after signalling the condition (unless a handler jumped somewhere
#' else via [rst_jump()] or by being [exiting()]). If `.critical` is
#' `TRUE`, the condition is signalled via [base::stop()] and the
#' program will terminate if no handler dealt with the condition by
#' jumping out of the distressed call frame.
#'
#' [calling()] handlers are called in turn when they decline to handle
#' the condition by returning normally. However, it is sometimes
#' useful for a calling handler to produce a side effect (signalling
#' another condition, displaying a message, logging something, etc),
#' prevent the condition from being passed to other handlers, and
#' resume execution from the place where the condition was
#' signalled. The easiest way to accomplish this is by jumping to a
#' restart point (see [with_restarts()]) established by the signalling
#' function. `cnd_signal()` always installs a muffle restart (see
#' [cnd_muffle()]).
#'
#' @section Lifecycle:
#'
#' * Modifying a condition object with `cnd_signal()` is defunct.
#'   Consequently the `.msg` and `.call` arguments are retired and
#'   defunct as of rlang 0.3.0.  In addition `.cnd` is renamed to
#'   `cnd` and soft-deprecated.
#'
#' * The `.mufflable` argument is soft-deprecated and no longer has
#'   any effect. Non-critical conditions are always signalled with a
#'   muffle restart.
#'
#' * Creating a condition object with [cnd_signal()] is
#'   soft-deprecated. Please use [signal()] instead.
#'
#' @param cnd A condition object (see [cnd()]).
#' @param .cnd,.mufflable These arguments are retired. `.cnd` has been
#'   renamed to `cnd` and `.mufflable` no longer has any effect as
#'   non-critical conditions are always signalled with a muffling
#'   restart.
#' @seealso [abort()], [warn()] and [inform()] for signalling typical
#'   R conditions. See [with_handlers()] for establishing condition
#'   handlers.
#' @export
#' @examples
#' # Creating a condition of type "foo"
#' cnd <- cnd("foo")
#'
#' # If no handler capable of dealing with "foo" is established on the
#' # stack, signalling the condition has no effect:
#' cnd_signal(cnd)
#'
#' # To learn more about establishing condition handlers, see
#' # documentation for with_handlers(), exiting() and calling():
#' with_handlers(cnd_signal(cnd),
#'   foo = calling(function(c) cat("side effect!\n"))
#' )
#'
#'
#' # By default, cnd_signal() creates a muffling restart which allows
#' # calling handlers to prevent a condition from being passed on to
#' # other handlers and to resume execution:
#' undesirable_handler <- calling(function(c) cat("please don't call me\n"))
#' muffling_handler <- calling(function(c) {
#'   cat("muffling foo...\n")
#'   cnd_muffle(c)
#' })
#'
#' with_handlers(foo = undesirable_handler,
#'   with_handlers(foo = muffling_handler, {
#'     cnd_signal(cnd("foo"))
#'     "return value"
#'   }))
cnd_signal <- function(cnd, .cnd, .mufflable) {
  validate_cnd_signal_args(cnd, .cnd, .mufflable)
  invisible(.Call(rlang_cnd_signal, cnd))
}
validate_cnd_signal_args <- function(cnd, .cnd, .mufflable,
                                     env = parent.frame()) {
  if (is_character(cnd)) {
    signal_soft_deprecated(paste_line(
      "Creating a condition with `cnd_signal()` is soft-deprecated as of rlang 0.3.0.",
      "Please use `signal()` instead."
    ))
    env$cnd <- cnd(cnd)
  }
  if (!missing(.cnd)) {
    signal_soft_deprecated(paste_line(
      "The `.cnd` argument is soft-deprecated as of rlang 0.3.0.",
      "Please use `cnd` instead."
    ))
    if (is_character(.cnd)) {
      signal_soft_deprecated(paste_line(
        "Creating a condition with `cnd_signal()` is soft-deprecated as of rlang 0.3.0.",
        "Please use `signal()` instead."
      ))
      .cnd <- cnd(.cnd)
    }
    env$cnd <- .cnd
  }
  if (!missing(.mufflable)) {
    signal_soft_deprecated(
      "`.mufflable` is soft-deprecated as of rlang 0.3.0 and no longer has any effect"
    )
  }
}

cnd_call <- function(call) {
  if (is_null(call) || is_false(call)) {
    return(NULL)
  }
  if (is_call(call)) {
    return(call)
  }

  if (is_true(call)) {
    call <- 1L
  } else if (!is_scalar_integerish(call, finite = TRUE)) {
    stop("`call` must be a scalar logical or number", call. = FALSE)
  }

  sys.call(sys.parent(call + 1L))
}


#' Signal an error, warning, or message
#'
#' @description
#'
#' These functions are equivalent to base functions [base::stop()],
#' [base::warning()] and [base::message()], but make it easy to supply
#' condition metadata:
#'
#' * Supply `.subclass` to create a classed condition. Typed
#'   conditions can be captured or handled selectively, allowing for
#'   finer-grained error handling.
#'
#' * Supply metadata with named `...` arguments. This data will be
#'   stored in the condition object and can be examined by handlers.
#'
#' `interrupt()` allows R code to simulate a user interrupt of the
#' kind that is signalled with `Ctrl-C`. It is currently not possible
#' to create custom interrupt condition objects.
#'
#'
#' @section Backtrace:
#'
#' Unlike `stop()` and `warning()`, these functions don't include call
#' information by default. This saves you from typing `call. = FALSE`
#' and produces cleaner error messages.
#'
#' A backtrace is always saved into error objects. You can print a
#' simplified backtrace of the last error by calling [last_error()]
#' and a full backtrace with `summary(last_error())`.
#'
#'
#' @section Mufflable conditions:
#'
#' Signalling a condition with `inform()` or `warn()` causes a message
#' to be displayed in the console. These messages can be muffled with
#' [base::suppressMessages()] or [base::suppressWarnings()].
#'
#' On recent R versions (>= R 3.5.0), interrupts are typically
#' signalled with a `"resume"` restart. This is however not
#' guaranteed.
#'
#'
#' @section Lifecycle:
#'
#' These functions were changed in rlang 0.3.0 to take condition
#' metadata with `...`. Consequently:
#'
#' * All arguments were renamed to be prefixed with a dot, except for
#'   `type` which was renamed to `.subclass`.
#' * `.call` (previously `call`) can no longer be passed positionally.
#'
#' @inheritParams cnd
#' @param message The message to display.
#' @param .subclass Subclass of the condition. This allows your users
#'   to selectively handle the conditions signalled by your functions.
#' @param ... Additional data to be stored in the condition object.
#' @param call Whether to display the call. If a number `n`, the call
#'   is taken from the nth frame on the [call stack][call_stack].
#' @param msg,type These arguments were renamed to `message` and
#'   `.type` and are deprecated as of rlang 0.3.0.
#'
#' @export
#' @examples
#' # These examples are guarded to avoid throwing errors
#' if (FALSE) {
#'
#' # Signal an error with a message just like stop():
#' abort("Something bad happened")
#'
#' # Give a class to the error:
#' abort("Something bad happened", "somepkg_bad_error")
#'
#' # This will allow your users to handle the error selectively
#' tryCatch(
#'   somepkg_function(),
#'   somepkg_bad_error = function(err) {
#'     warn(err$message) # Demote the error to a warning
#'     NA                # Return an alternative value
#'   }
#' )
#'
#' # You can also specify metadata that will be stored in the condition:
#' abort("Something bad happened", "somepkg_bad_error", data = 1:10)
#'
#' # This data can then be consulted by user handlers:
#' tryCatch(
#'   somepkg_function(),
#'   somepkg_bad_error = function(err) {
#'     # Compute an alternative return value with the data:
#'     recover_error(err$data)
#'   }
#' )
#'
#' # If you call low-level APIs it is good practice to catch technical
#' # errors and rethrow them with a more meaningful message. Pass on
#' # the caught error as `parent` to get a nice decomposition of
#' # errors and backtraces:
#' file <- "http://foo.bar/baz"
#' tryCatch(
#'   download(file),
#'   error = function(err) {
#'     msg <- sprintf("Can't download `%s`", file)
#'     abort(msg, parent = err)
#' })
#'
#' # Unhandled errors are saved automatically by `abort()` and can be
#' # retrieved with `last_error()`. The error prints with a simplified
#' # backtrace:
#' abort("Saved error?")
#' last_error()
#'
#' # Use `summary()` to print the full backtrace and the condition fields:
#' summary(last_error())
#'
#' }
abort <- function(message, .subclass = NULL,
                  ...,
                  trace = NULL,
                  call = NULL,
                  parent = NULL,
                  msg, type) {
  validate_signal_args(msg, type)

  if (is_null(trace)) {
    trace <- trace_back()

    if (is_null(parent)) {
      context <- trace_length(trace)
    } else {
      context <- find_capture_context()
    }
    trace <- trace_trim_context(trace, context)
  }

  cnd <- error_cnd(.subclass,
    ...,
    message = message,
    call = cnd_call(call),
    parent = parent,
    trace = trace
  )

  stop(cnd)
}

trace_trim_context <- function(trace, frame = caller_env()) {
  if (is_environment(frame)) {
    idx <- detect_index(trace$envs, identical, env_label(frame))
  } else if (is_scalar_integerish(frame)) {
    idx <- frame
  } else {
    abort("`frame` must be a frame environment or index")
  }

  to_trim <- seq2(idx, trace_length(trace))
  if (length(to_trim)) {
    trace <- trace_subset(trace, -to_trim)
  }

  trace
}
# FIXME: Find more robust strategy of stripping catching context
find_capture_context <- function(n = 3L) {
  sys_parent <- sys.parent(n)
  thrower_frame <- sys.frame(sys_parent)

  call <- sys.call(sys_parent)
  frame <- sys.frame(sys_parent)
  if (!is_call(call, "tryCatchOne") || !env_inherits(frame, ns_env("base"))) {
    return(thrower_frame)
  }

  sys_parents <- sys.parents()
  while (!is_call(call, "tryCatch")) {
    sys_parent <- sys_parents[sys_parent]
    call <- sys.call(sys_parent)
  }

  next_parent <- sys_parents[sys_parent]
  call <- sys.call(next_parent)
  if (is_call(call, "with_handlers")) {
    sys_parent <- next_parent
  }

  sys.frame(sys_parent)
}


#' @rdname abort
#' @export
warn <- function(message, .subclass = NULL, ..., call = NULL, msg, type) {
  validate_signal_args(msg, type)

  cnd <- warning_cnd(.subclass, ..., message = message, call = cnd_call(call))
  warning(cnd)
}
#' @rdname abort
#' @export
inform <- function(message, .subclass = NULL, ..., call = NULL, msg, type) {
  validate_signal_args(msg, type, call)

  message <- paste0(message, "\n")
  cnd <- message_cnd(.subclass, ..., message = message, call = cnd_call(call))
  message(cnd)
}
#' @rdname abort
#' @export
signal <- function(message, .subclass, ..., call = NULL) {
  cnd <- cnd(.subclass, ..., message = message, call = cnd_call(call))
  cnd_signal(cnd)
}
validate_signal_args <- function(msg, type, env = parent.frame()) {
  if (!missing(msg)) {
    warn_deprecated("`msg` has been renamed to `message` and is deprecated as of rlang 0.3.0")
    env$message <- msg
  }
  if (!missing(type)) {
    warn_deprecated("`type` has been renamed to `.subclass` and is deprecated as of rlang 0.3.0")
    env$.subclass <- type
  }
}
#' @rdname abort
#' @export
interrupt <- function() {
  .Call(rlang_interrupt)
}

#' Muffle a condition
#'
#' Unlike [exiting()] handlers, [calling()] handlers must be explicit
#' that they have handled a condition to stop it from propagating to
#' other handlers. Use `cnd_muffle()` within a calling handler (or as
#' a calling handler, see examples) to prevent any other handlers from
#' being called for that condition.
#'
#'
#' @section Mufflable conditions:
#'
#' Most conditions signalled by base R are muffable, although the name
#' of the restart varies. cnd_muffle() will automatically call the
#' correct restart for you. It is compatible with the following
#' conditions:
#'
#' * `warning` and `message` conditions. In this case `cnd_muffle()`
#'   is equivalent to [base::suppressMessages()] and
#'   [base::suppressWarnings()].
#'
#' * Bare conditions signalled with `signal()` or [cnd_signal()]. Note
#'   that conditions signalled with [base::signalCondition()] are not
#'   mufflable.
#'
#' * Interrupts are sometimes signalled with a `resume` restart on
#'   recent R versions. When this is the case, you can muffle the
#'   interrupt with `cnd_muffle()`. Check if a restart is available
#'   with `base::findRestart("resume")`.
#'
#' If you call `cnd_muffle()` with a condition that is not mufflable
#' you will cause a new error to be signalled.
#'
#' * Errors are not mufflable since they are signalled in critical
#'   situations where execution cannot continue safely.
#'
#' * Conditions captured with [base::tryCatch()], [with_handlers()] or
#'   [catch_cnd()] are no longer mufflable. Muffling restarts _must_
#'   be called from a [calling] handler.
#'
#' @param cnd A condition to muffle.
#'
#' @export
#' @examples
#' fn <- function() {
#'   inform("Beware!", "my_particular_msg")
#'   inform("On your guard!")
#'   "foobar"
#' }
#'
#' # Let's install a muffling handler for the condition thrown by `fn()`.
#' # This will suppress all `my_particular_wng` warnings but let other
#' # types of warnings go through:
#' with_handlers(fn(),
#'   my_particular_msg = calling(function(cnd) {
#'     inform("Dealt with this particular message")
#'     cnd_muffle(cnd)
#'   })
#' )
#'
#' # Note how execution of `fn()` continued normally after dealing
#' # with that particular message.
#'
#' # Since cnd_muffle() is a calling handler itself, it can also be
#' # passed to with_handlers() directly:
#' with_handlers(fn(),
#'   my_particular_msg = cnd_muffle
#' )
cnd_muffle <- function(cnd) {
  switch(cnd_type(cnd),
    message = invokeRestart("muffleMessage"),
    warning = invokeRestart("muffleWarning"),
    interrupt = invokeRestart("resume")
  )
  if (inherits(cnd, "rlang_condition")) {
    invokeRestart("rlang_muffle")
  }

  abort("Can't find a muffling restart")
}
class(cnd_muffle) <- c("calling", "handler")

#' Catch a condition
#'
#' This is a small wrapper around `tryCatch()` that captures any
#' condition signalled while evaluating its argument. It is useful for
#' debugging and unit testing.
#'
#' @param expr Expression to be evaluated with a catch-all condition
#'   handler.
#' @return A condition if any was signalled, `NULL` otherwise.
#' @export
#' @examples
#' catch_cnd(10)
#' catch_cnd(abort("an error"))
#' catch_cnd(cnd_signal("my_condition", .msg = "a condition"))
catch_cnd <- function(expr) {
  tryCatch(condition = identity, {
    force(expr)
    return(NULL)
  })
}

#' @export
print.rlang_error <- function(x,
                              ...,
                              child = NULL,
                              simplify = c("collapse", "branch", "none"),
                              fields = FALSE) {
  if (is_null(child)) {
    header <- "<error>"
  } else {
    header <- "<error: parent>"
  }
  cat_line(
    header,
    sprintf("* Message: \"%s\"", x$message),
    sprintf("* Class: `%s`", class(x)[[1]])
  )

  if (fields) {
    nms <- chr_enumerate(chr_quoted(names(x)), final = "and")
    cat_line(sprintf("* Fields: %s", nms))
  }

  cat_line("* Backtrace:")

  trace <- x$trace
  if (!is_null(child)) {
    # Trim common portions of backtrace
    child_trace <- child$trace
    common <- map_lgl(trace$envs, `%in%`, child_trace$envs)
    trace <- trace_subset(trace, which(!common))

    # Trim catching context if any
    calls <- trace$calls
    if (length(calls) && is_call(calls[[1]], c("tryCatch", "with_handlers"))) {
      parent <- trace$parents[[1]]
      next_sibling <- which(trace$parents[-1] == parent)
      if (length(next_sibling)) {
        trace <- trace_subset(trace, -seq2(1L, next_sibling))
      }
    }
  }

  simplify <- arg_match(simplify, c("collapse", "branch", "none"))
  print(trace, ..., simplify = simplify)

  if (!is_null(x$parent)) {
    print(x$parent, ..., child = x, simplify = simplify, fields = fields)
  }

  invisible(x)
}

# Last error to be returned in last_error()
last_error_env <- new.env(parent = emptyenv())
last_error_env$cnd <- NULL

#' @export
summary.rlang_error <- function(object, ...) {
  print(object, simplify = "none", fields = TRUE)
}

#' @export
conditionMessage.rlang_error <- function(c) {
  last_error_env$cnd <- c

  lines <- c$message
  trace <- format(c$trace, simplify = "branch", max_frames = 10L)

  parents <- chr()
  while(is_condition(c$parent)) {
    c <- c$parent
    parents <- chr(parents, c$message)
  }

  if (length(parents)) {
    parents <- cli_branch(parents)
    lines <- paste_line(lines,
      "Parents:",
      parents
    )
  }

  if (!is_null(trace)) {
    lines <- paste_line(
      lines,
      "Backtrace:",
      trace
    )
  }

  lines
}

#' Signal deprecation
#'
#' `signal_soft_deprecated()` warns only if option is set, the package
#'  is attached, or if called from the global environment.
#'  `warn_deprecated()` warns unconditionally. Both functions warn
#'  only once.
#'
#' @param msg The deprecation message.
#' @param id The id of the deprecation. A warning is issued only once
#'   for each `id`. Defaults to `msg`, but you should give a unique ID
#'   when the message is built programmatically and depends on inputs.
#' @param package The soft-deprecation warning is forced when this
#'   package is attached. Automatically detected from the caller
#'   environment.
#'
#' @noRd
NULL

signal_soft_deprecated <- function(msg, id = msg, package = NULL) {
  if (is_true(peek_option("lifecycle_disable_verbose_retirement"))) {
    return(invisible(NULL))
  }

  if (is_true(peek_option("lifecycle_force_verbose_retirement")) ||
      is_reference(caller_env(2), global_env())) {
    warn_deprecated(msg, id)
    return(invisible(NULL))
  }

  if (is_null(package)) {
    top <- topenv(caller_env())
    if (!is_namespace(top)) {
      abort("`signal_soft_deprecated()` must be called from a package function")
    }
    package <- ns_env_name(top)
  } else {
    stopifnot(is_string(package))
  }

  package <- paste0("package:", package)

  if (package %in% search()) {
    warn_deprecated(msg, id)
    return(invisible(NULL))
  }

  signal(msg, "lifecycle_soft_deprecated")
}

warn_deprecated <- function(msg, id = msg) {
  if (is_true(peek_option("lifecycle_disable_verbose_retirement"))) {
    return(invisible(NULL))
  }

  .Call(rlang_warn_deprecated_once, id, msg)
}
deprecation_env <- new.env(parent = emptyenv())

abort_defunct <- function(msg) {
  .Defunct(msg = msg)
}
