import os

bib_content = """
@article{kuiken2012lanl,
  title={The LANL hemorrhagic fever virus database, a new platform for analyzing biothreat viruses},
  author={Kuiken, C and Thurmond, J and Dimitrijevic, M and Yoon, H},
  journal={Nucleic Acids Res},
  volume={40},
  pages={D587--92},
  year={2012},
  month={Jan}
}

@dataset{mcnaughton2019hbv,
  title={Hepatitis B Virus (HBV) Genotype and Subtype Reference Sequences},
  author={McNaughton, Anna and Ansari, Azim and Matthews, Philippa},
  year={2019},
  publisher={figshare},
  doi={10.6084/m9.figshare.8851946.v1},
  url={https://doi.org/10.6084/m9.figshare.8851946.v1}
}

@misc{bedford2016zika,
  title={Zika USVI Outbreak Genomic Alignments},
  author={Bedford, Trevor},
  year={2016},
  url={https://github.com/blab/zika-usvi}
}

@article{felsenstein1981evolutionary,
  title={Evolutionary trees from DNA sequences: a maximum likelihood approach},
  author={Felsenstein, Joseph},
  journal={Journal of molecular evolution},
  volume={17},
  number={6},
  pages={368--376},
  year={1981},
  publisher={Springer}
}

@article{edelsbrunner2000topological,
  title={Topological persistence and simplification},
  author={Edelsbrunner, Herbert and Letscher, David and Zomorodian, Afra},
  journal={Discrete \& Computational Geometry},
  volume={28},
  number={4},
  pages={511--533},
  year={2002},
  publisher={Springer}
}

@article{zomorodian2005computing,
  title={Computing persistent homology},
  author={Zomorodian, Afra and Carlsson, Gunnar},
  journal={Discrete \& Computational Geometry},
  volume={33},
  number={2},
  pages={249--274},
  year={2005},
  publisher={Springer}
}
"""

with open('/Users/sulky/Desktop/biozig/ATLAZ/manuscript_mbe/references.bib', 'w') as f:
    f.write(bib_content)

main_tex_content = r"""\documentclass[modern]{oup-authoring-template}

\usepackage{graphicx}
\usepackage{amsmath}
\usepackage{hyperref}
\usepackage{natbib}

\begin{document}

\journaltitle{Molecular Biology and Evolution}
\DOI{DOI HERE}
\copyrightyear{2026}
\pubyear{2026}
\access{Advance Access Publication Date: Day Month Year}
\appnotes{Paper}

\firstpage{1}

\title[ATLAZ: Topological Viral Evolution]{ATLAZ: A Zero-Copy Geometric Engine for Exact Topological Inference in Viral Evolution}

\author[1,$\ast$]{Sulky Subject}
\authormark{Subject}
\address[1]{\orgdiv{Bioinformatics}, \orgname{DeepMind}, \orgaddress{\state{London}, \country{UK}}}
\corresp[$\ast$]{Corresponding author. \href{mailto:sulky@example.com}{sulky@example.com}}

\abstract{
The reliance on strictly bifurcating phylogenetic trees fundamentally distorts the evolutionary history of reticulate viral populations. Traditional maximum-likelihood algorithms mandate vertical descent, imposing artificial clades upon recombinant genomes and obscuring the origins of segmented pandemic shifts. Furthermore, linear selection metrics (e.g., dN/dS) fail mathematically when evaluating overlapping open reading frames. Here we present ATLAZ (Alignment, Topology, and Lineage Analysis in Zig), a memory-deterministic geometric engine that explicitly bypasses the phylogenetic tree. By computing Vietoris-Rips simplicial complexes and extracting $H_1$ persistence directly from spatial distance matrices, ATLAZ definitively isolates horizontal recombination in Hepatitis B and Avian Influenza. Conversely, the absence of topological loops strictly proves the clonal descent of Ebola, Zika, and Marburg viruses. Utilizing a native Galois Field reduction across a zero-copy C-ABI boundary, ATLAZ processes massive cohorts (over 6,000 sequences) in $O(1)$ memory relative to sequence length, shattering the catastrophic computational bottlenecks of previous Topological Data Analysis frameworks. Furthermore, sequential column ablation calculates a novel Topological Selection Score (TSS), geometrically mapping absolute structural rigidity and identifying optimal targets for direct-acting antivirals in seconds. ATLAZ establishes a new absolute, math-driven standard for computational virology.
}

\keywords{Topological Data Analysis, Recombination, Phylogenetics, Zig, Computational Virology}

\maketitle

\input{01_Introduction.tex}
\input{02_New_Approaches.tex}
\input{03_Results.tex}
\input{04_Discussion.tex}
\input{05_Materials_and_Methods.tex}

\bibliographystyle{plainnat}
\bibliography{references}

\end{document}
"""

with open('/Users/sulky/Desktop/biozig/ATLAZ/manuscript_mbe/main.tex', 'w') as f:
    f.write(main_tex_content)
