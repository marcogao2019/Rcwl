% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/writeCWL.R
\name{writeCWL}
\alias{writeCWL}
\title{Write CWL}
\usage{
writeCWL(cwl, prefix, docker = TRUE, ...)
}
\arguments{
\item{cwl}{A `cwlParam` or `cwlStepParam` object.}

\item{prefix}{The prefix of `cwl` and `yml` file to write.}

\item{docker}{Whether to use docker.}

\item{...}{Other options from `yaml::write_yaml`.}
}
\value{
A CWL file and A YML file.
}
\description{
write `cwlParam` to cwl and yml.
}
\examples{
input1 <- InputParam(id = "sth")
echo <- cwlParam(baseCommand = "echo",
                 inputs = InputParamList(input1))
tf <- tempfile()
writeCWL(echo, tf)
}
