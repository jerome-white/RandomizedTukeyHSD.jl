# Glossary

The data are a randomized block design: one measurement of every treatment in
every block. The package uses the statistical names for the three parts and
maps to the words of the fields it is used in:

| Here        | In information retrieval | In machine learning   | Formerly |
|-------------|--------------------------|-----------------------|----------|
| block       | topic                    | dataset, fold, seed   | topic    |
| treatment   | system                   | model, method         | system   |
| response    | score                    | metric, accuracy      | score    |
| `trials`    | B                        | number of resamples   | `B`      |

The method comes from information retrieval, so the citations and the
reference tests (which compare with Sakai's code) keep that tool's own words
where they quote it. Earlier versions of this package, its issues and its pull
requests used the words in the last column.

Two more words describe how the blocks were sampled (see
[What counts as a block](@ref)). A *cluster* is a group of blocks sampled
together, whose responses are correlated within a treatment, such as several
questions about one passage; the cluster then becomes the block. A *stratum*
is a group of blocks fixed by the design, such as one subject of a benchmark;
its blocks stay as they are.
