#' @export
biozig_context_create <- function() {
    res <- .Call("r_biozig_context_create")
    if (res != 0) {
        stop("Failed to initialize BioZig context")
    }
    return(invisible(res))
}

#' @export
biozig_context_destroy <- function() {
    res <- .Call("r_biozig_context_destroy")
    if (res != 0) {
        stop("Failed to destroy BioZig context")
    }
    return(invisible(res))
}

#' @export
biozig_ping <- function() {
    return(.Call("r_biozig_ping"))
}
