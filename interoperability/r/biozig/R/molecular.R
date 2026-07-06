#' @export
biozig_shannon_entropy <- function(seq) {
    if (!is.character(seq) || length(seq) != 1) {
        stop("seq must be a single string")
    }
    return(.Call("r_biozig_shannon_entropy", seq))
}

#' @export
biozig_translate_dna <- function(seq) {
    if (!is.character(seq) || length(seq) != 1) {
        stop("seq must be a single string")
    }
    res <- .Call("r_biozig_translate_dna", seq)
    if (is.null(res)) {
        stop("Translation failed")
    }
    return(res)
}

#' @export
biozig_align_global <- function(seq_a, seq_b, match_score = 1, mismatch_penalty = -1, gap_penalty = -1) {
    if (!is.character(seq_a) || length(seq_a) != 1) {
        stop("seq_a must be a single string")
    }
    if (!is.character(seq_b) || length(seq_b) != 1) {
        stop("seq_b must be a single string")
    }
    res <- .Call("r_biozig_align_global", seq_a, seq_b, match_score, mismatch_penalty, gap_penalty)
    return(res)
}
