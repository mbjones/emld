% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/as_emld.R
\name{as_emld}
\alias{as_emld}
\title{Coerce an EML file or object into an emld object.}
\usage{
as_emld(x, from = c("guess", "xml", "json", "list"))
}
\arguments{
\item{x}{path to an EML file}

\item{from}{explicit type for the input format. By default, will
attempt to guess the format, but it always safer to specify the
input format. This is essential for literal text strings or raw
vectors where the type cannot be guessed by the R object class
or file extension of the input.}
}
\value{
an emld object
}
\description{
Coerce an EML file or object into an emld object.
}
\examples{
 hf205 <- system.file("extdata/hf205.xml", package="emld")
 as_emld(hf205)
}
