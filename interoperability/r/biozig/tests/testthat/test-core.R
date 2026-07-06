test_that("BioZig core tests", {
  expect_error(biozig_context_create(), NA)
  expect_error(biozig_context_create(), "Failed to initialize BioZig context")
  
  ping_res <- biozig_ping()
  expect_equal(ping_res, 42)
  
  # molecular tests
  ent <- biozig_shannon_entropy("ATGC")
  expect_type(ent, "double")
  
  prot <- biozig_translate_dna("ATGCGT")
  expect_type(prot, "character")
  expect_equal(prot, "MR")
  
  aln <- biozig_align_global("ATGC", "ATGC")
  expect_type(aln, "list")
  expect_equal(aln$score, 4)
  expect_equal(aln$aligned_a, "ATGC")
  expect_equal(aln$aligned_b, "ATGC")
  
  expect_error(biozig_context_destroy(), NA)
  expect_error(biozig_context_destroy(), "Failed to destroy BioZig context")
})
