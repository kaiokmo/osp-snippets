#!/usr/bin/env python3

import pickle
import json


def pickle_dump(filename):
    with open(filename, 'rb') as f:
        data = pickle.load(f)
    print(json.dumps(data))


if __name__ == '__main__':
    import sys

    for name in sys.argv[1:]:
        pickle_dump(name)
