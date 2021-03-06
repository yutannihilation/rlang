% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/lifecycle-retired.R
\name{stack}
\alias{stack}
\alias{global_frame}
\alias{current_frame}
\alias{ctxt_frame}
\alias{call_frame}
\alias{ctxt_depth}
\alias{call_depth}
\alias{ctxt_stack}
\alias{call_stack}
\title{Call stack information}
\usage{
global_frame()

current_frame()

ctxt_frame(n = 1)

call_frame(n = 1, clean = TRUE)

ctxt_depth()

call_depth()

ctxt_stack(n = NULL, trim = 0)

call_stack(n = NULL, clean = TRUE)
}
\arguments{
\item{n}{The number of frames to go back in the stack.}

\item{clean}{Whether to post-process the call stack to clean
non-standard frames. If \code{TRUE}, suboptimal call-stack entries by
\code{\link[base:eval]{base::eval()}} will be cleaned up: the duplicate frame created by
\code{eval()} is eliminated.}

\item{trim}{The number of layers of intervening frames to trim off
the stack. See \code{\link[=stack_trim]{stack_trim()}} and examples.}
}
\description{
\Sexpr[results=rd, stage=render]{rlang:::lifecycle("soft-deprecated")}

The \code{eval_} and \code{call_} families of functions provide a replacement
for the base R functions prefixed with \code{sys.} (which are all about
the context stack), as well as for \code{\link[=parent.frame]{parent.frame()}} (which is the
only base R function for querying the call stack). The context
stack includes all R-level evaluation contexts. It is linear in
terms of execution history but due to lazy evaluation it is
potentially nonlinear in terms of call history. The call stack
history, on the other hand, is homogenous.
}
\details{
\code{ctxt_frame()} and \code{call_frame()} return a \code{frame} object
containing the following fields: \code{expr} and \code{env} (call expression
and evaluation environment), \code{pos} and \code{caller_pos} (position of
current frame in the context stack and position of the caller), and
\code{fun} (function of the current frame). \code{ctxt_stack()} and
\code{call_stack()} return a list of all context or call frames on the
stack. Finally, \code{ctxt_depth()} and \code{call_depth()} report the
current context position or the number of calling frames on the
stack.

The base R functions take two sorts of arguments to indicate which
frame to query: \code{which} and \code{n}. The \code{n} argument is
straightforward: it's the number of frames to go down the stack,
with \code{n = 1} referring to the current context. The \code{which} argument
is more complicated and changes meaning for values lower than 1.
For the sake of consistency, the rlang functions all take the
same kind of argument \code{n}. This argument has a single meaning (the
number of frames to go down the stack) and cannot be lower than 1.

Note finally that \code{parent.frame(1)} corresponds to
\code{call_frame(2)$env}, as \code{n = 1} always refers to the current
frame. This makes the \code{_frame()} and \code{_stack()} functions
consistent: \code{ctxt_frame(2)} is the same as \code{ctxt_stack()[[2]]}.
Also, \code{ctxt_depth()} returns one more frame than
\code{\link[base:sys.nframe]{base::sys.nframe()}} because it counts the global frame. That is
consistent with the \code{_stack()} functions which return the global
frame as well. This way, \code{call_stack(call_depth())} is the same as
\code{global_frame()}.
}
\section{Life cycle}{


These functions are soft-deprecated and replaced by \code{\link[=trace_back]{trace_back()}}.
}

\examples{
# Expressions within arguments count as contexts
identity(identity(ctxt_depth())) # returns 2

# But they are not part of the call stack because arguments are
# evaluated within the calling function (or the global environment
# if called at top level)
identity(identity(call_depth())) # returns 0

# The context stacks includes all intervening execution frames. The
# call stack doesn't:
f <- function(x) identity(x)
f(f(ctxt_stack()))
f(f(call_stack()))

g <- function(cmd) cmd()
f(g(ctxt_stack))
f(g(call_stack))

# The rlang _stack() functions return a list of frame
# objects. Use purrr::transpose() or index a field with
# purrr::map()'s to extract a particular field from a stack:

# stack <- f(f(call_stack()))
# purrr::map(stack, "env")
# purrr::transpose(stack)$expr

# current_frame() is an alias for ctxt_frame(1)
fn <- function() list(current = current_frame(), first = ctxt_frame(1))
fn()

# While current_frame() is the top of the stack, global_frame() is
# the bottom:
fn <- function() {
  n <- ctxt_depth()
  ctxt_frame(n)
}
identical(fn(), global_frame())


# ctxt_stack() returns a stack with all intervening frames. You can
# trim layers of intervening frames with the trim argument:
identity(identity(ctxt_stack()))
identity(identity(ctxt_stack(trim = 1)))

# ctxt_stack() is called within fn() with intervening frames:
fn <- function(trim) identity(identity(ctxt_stack(trim = trim)))
fn(0)

# We can trim the first layer of those:
fn(1)

# The outside intervening frames (at the fn() call site) are still
# returned, but can be trimmed as well:
identity(identity(fn(1)))
identity(identity(fn(2)))

g <- function(trim) identity(identity(fn(trim)))
g(2)
g(3)
}
\keyword{internal}
