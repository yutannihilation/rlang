% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/topic-nse.R
\name{topic-data-mask-ambiguity}
\alias{topic-data-mask-ambiguity}
\title{The data mask ambiguity}
\description{
\link[=topic-data-mask]{Data masking} is an R feature that blends programming variables that live inside environments (env-variables) with statistical variables stored in data frames (data-variables). This mixture makes it easy to refer to data frame columns as well as objects defined in the current environment.

\if{html}{\out{<div class="sourceCode r">}}\preformatted{x <- 100
mtcars \%>\% dplyr::summarise(mean(disp / x))
#> # A tibble: 1 x 1
#>   `mean(disp/x)`
#>            <dbl>
#> 1           2.31
}\if{html}{\out{</div>}}

However this convenience introduces an ambiguity between data-variables and env-variables which might cause \strong{collisions}.
\subsection{Column collisions}{

In the following snippet, are we referring to the env-variable \code{x} or to the data-variable of the same name?

\if{html}{\out{<div class="sourceCode r">}}\preformatted{df <- data.frame(x = NA, y = 2)
x <- 100

df \%>\% dplyr::mutate(y = y / x)
#>    x  y
#> 1 NA NA
}\if{html}{\out{</div>}}

A column collision occurs when you want to use an object defined outside of the data frame, but a column of the same name happens to exist.
}

\subsection{Object collisions}{

The opposite problem occurs when there is a typo in a data-variable name and an env-variable of the same name exists:

\if{html}{\out{<div class="sourceCode r">}}\preformatted{df <- data.frame(foo = "right")
ffo <- "wrong"

df \%>\% dplyr::mutate(foo = toupper(ffo))
#>     foo
#> 1 WRONG
}\if{html}{\out{</div>}}

Instead of a typo, it might also be that you were expecting a column in the data frame which is unexpectedly missing. In both cases, if a variable can't be found in the data mask, R looks for variables in the surrounding environment. This isn't what we intended here and it would have been better to fail early with a "Column not found" error.
}

\subsection{Preventing collisions}{

In casual scripts or interactive programming, data mask ambiguity is not a huge deal compared to the payoff of iterating quickly while developing your analysis. However in production code and in package functions, the ambiguity might cause collision bugs in the long run.

Fortunately it is easy to be explicit about the scoping of variables with a little more verbose code. This topic lists the solutions and workarounds that have been created to solve ambiguity issues in data masks.
\subsection{The \code{.data} and \code{.env} pronouns}{

The simplest solution is to use the \code{\link{.data}} and \code{\link{.env}} pronouns to disambiguate between data-variables and env-variables.

\if{html}{\out{<div class="sourceCode r">}}\preformatted{df <- data.frame(x = 1, y = 2)
x <- 100

df \%>\% dplyr::mutate(y = .data$y / .env$x)
#>   x    y
#> 1 1 0.02
}\if{html}{\out{</div>}}

This is especially useful in functions because the data frame is not known in advance and potentially contain masking columns for any of the env-variables in scope in the function:

\if{html}{\out{<div class="sourceCode r">}}\preformatted{my_rescale <- function(data, var, factor = 10) \{
  data \%>\% dplyr::mutate("\{\{ var \}\}" := \{\{ var \}\} / factor)
\}

# This works
data.frame(value = 1) \%>\% my_rescale(value)
#>   value
#> 1   0.1
}\if{html}{\out{</div>}}

\if{html}{\out{<div class="sourceCode r">}}\preformatted{
# Oh no!
data.frame(factor = 0, value = 1) \%>\% my_rescale(value)
#>   factor value
#> 1      0   Inf
}\if{html}{\out{</div>}}

Subsetting function arguments with \code{.env} ensures we never hit a masking column:

\if{html}{\out{<div class="sourceCode r">}}\preformatted{my_rescale <- function(data, var, factor = 10) \{
  data \%>\% dplyr::mutate("\{\{ var \}\}" := \{\{ var \}\} / .env$factor)
\}

# Yay!
data.frame(factor = 0, value = 1) \%>\% my_rescale(value)
#>   factor value
#> 1      0   0.1
}\if{html}{\out{</div>}}
}

\subsection{Subsetting \code{.data} with env-variables}{

The \code{\link{.data}} pronoun may be used as a name-to-data-mask pattern (see \ifelse{html}{\link[=topic-data-mask-programming]{Data mask programming patterns}}{\link[=topic-data-mask-programming]{Data mask programming patterns}}):

\if{html}{\out{<div class="sourceCode r">}}\preformatted{var <- "cyl"
mtcars \%>\% dplyr::summarise(mean = mean(.data[[var]]))
#> # A tibble: 1 x 1
#>    mean
#>   <dbl>
#> 1  6.19
}\if{html}{\out{</div>}}

In this example, the env-variable \code{var} is used inside the data mask to subset the \code{.data} pronoun. Does this mean that \code{var} is at risk of a column collision if the input data frame contains a column of the same name? Fortunately not:

\if{html}{\out{<div class="sourceCode r">}}\preformatted{var <- "cyl"

mtcars2 <- mtcars
mtcars2$var <- "wrong"

mtcars2 \%>\% dplyr::summarise(mean = mean(.data[[var]]))
#> # A tibble: 1 x 1
#>    mean
#>   <dbl>
#> 1  6.19
}\if{html}{\out{</div>}}

The evaluation of \code{.data[[var]]} is set up in such a way that there is no ambiguity. The \code{.data} pronoun can only be subsetted with env-variables, not data-variables. Technically, this is because \code{[[} behaves like an \emph{injection operator} when applied to \code{.data}. It is evaluated very early before the data mask is even created. See the \verb{!!} section below.
}

\subsection{Injecting env-variables with \verb{!!}}{

\link[=topic-inject]{Injection operators} such as \code{\link[=injection-operator]{!!}} have interesting properties regarding the ambiguity problem. They modify a piece of code early on by injecting objects or other expressions before any data-masking logic comes into play. If you inject the \emph{value} of a variable, it becomes inlined in the expression. R no longer needs to look up any variable to find the value.

Taking the earlier division example, let's use \verb{!!} to inject the value of the env-variable \code{x} inside the division expression:

\if{html}{\out{<div class="sourceCode r">}}\preformatted{df <- data.frame(x = NA, y = 2)
x <- 100

df \%>\% dplyr::mutate(y = y / !!x)
#>    x    y
#> 1 NA 0.02
}\if{html}{\out{</div>}}

While injection solves issues of ambiguity, it is a bit heavy handed compared to using the \code{\link{.env}} pronoun. Big objects inlined in expressions might cause issues in unexpected places, for instance they might make the calls in a \code{\link[=traceback]{traceback()}} less readable.
}

}

\subsection{No ambiguity in tidy selections}{

\href{https://tidyselect.r-lib.org/reference/language.html}{Tidy selection} is a dialect of R that optimises column selection in tidyverse packages. Examples of functions that use tidy selections are \code{dplyr::select()} and \code{tidyr::pivot_longer()}.

Unlike data masking, tidy selections do not suffer from ambiguity. The selection language is designed in such a way that evaluation of expressions is either scoped in the data mask only, or in the environment only. Take this example:

\if{html}{\out{<div class="sourceCode r">}}\preformatted{mtcars \%>\% dplyr::select(gear:ncol(mtcars))
}\if{html}{\out{</div>}}

\code{gear} is a symbol supplied to a selection operator \code{:} and thus scoped in the data mask only. Any other kind of expression, such as \code{ncol(mtcars)}, is evaluated as normal R code outside of any data context. This is why there is no column collision here:

\if{html}{\out{<div class="sourceCode r">}}\preformatted{data <- data.frame(x = 1, data = 1:3)

data \%>\% dplyr::select(data:ncol(data))
#>   data
#> 1    1
#> 2    2
#> 3    3
}\if{html}{\out{</div>}}

It is useful to introduce two new terms. Tidy selections distinguish data-expressions and env-expressions:
\itemize{
\item \code{data} is a data-expression that refers to the data-variable.
\item \code{ncol(data)} is an env-expression that refers to the env-variable.
}

To learn more about the difference between the two kinds of expressions, see the \href{https://tidyselect.r-lib.org/articles/syntax.html}{technical description of the tidy selection syntax}.
\subsection{Names pattern with \code{all_of()}}{

\code{all_of()} is often used in functions as a \link[=topic-data-mask-programming]{programming pattern} that connects column names to a data mask, similarly to the \code{\link{.data}} pronoun. A simple example is:

\if{html}{\out{<div class="sourceCode r">}}\preformatted{my_group_by <- function(data, vars) \{
  data \%>\% dplyr::group_by(across(all_of(vars)))
\}
}\if{html}{\out{</div>}}

If tidy selections were affected by the data mask ambiguity, this function would be at risk of a column collision. It would break as soon as the user supplies a data frame containing a \code{vars} column. However, \code{all_of()} is an env-expression that is evaluated outside of the data mask, so there is no possibility of collisions.
}

}
}
\keyword{internal}
