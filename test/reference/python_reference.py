"""Writes the reference p-values for a tidy CSV (topic,system,score) using
the Python RandomisedTukey implementation from the original sakai-book
repository, which has to be importable:

    PYTHONPATH=/path/to/sakai-book python3 python_reference.py \
        ../data/generic.csv 1000000 8 > ../data/generic_python.csv

The multiprocessing pool needs the __main__ guard below: on macOS Python
starts workers with "spawn", which re-imports the calling script.
"""
import sys

from irstats import Scores, RandomisedTukey


def main(path, B, workers):
    with open(path) as fp:
        scores = Scores.from_csv(fp)

    print('system1,system2,difference,p')
    for r in RandomisedTukey(scores, B, workers):
        print(r.system1, r.system2, r.difference, r.p, sep=',')


if __name__ == '__main__':
    main(sys.argv[1], int(sys.argv[2]), int(sys.argv[3]))
