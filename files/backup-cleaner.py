#!/usr/bin/env python
import argparse
import os
from os import path
import sys
import datetime

parser = argparse.ArgumentParser(description='Script used for cleaning backup files if they expired')
parser.add_argument(
    '-d', '--directory',
    help='base directory path to clean',
    required=True
)
parser.add_argument(
    '-e', '--expiry',
    help='Expiry time in days',
    type=int,
    default=30
)
parser.add_argument(
    '-r', '--recursive',
    help='argument which enable/disable recursive execution',
    type=bool,
    default=True
)
parser.add_argument(
    '--leave-empty-dirs',
    help="flag which force to leave empty directories, work only when 'recursive' argument is true",
    default=False,
    action='store_true'
)
parser.add_argument(
    '-v',
    help="flag which enables verbose execution",
    default=False,
    action='store_true'
)


class BackupCleaner:
    directory = ''

    expiry_in_seconds = 30

    recursive = True

    delete_empty_dirs = False

    verbose = False

    counters = {
        'total': {
            'files': 0,
            'directories': 0,
            'bytes': 0,

        },
        'deleted': {
            'files': 0,
            'directories': 0,
            'bytes': 0
        }
    }

    def __init__(self, directory, expiry_in_days, recursive, delete_empty_dirs, verbose):
        if not path.isdir(directory):
            raise AttributeError("Cannot find directory: {0}".format(directory))
        self.directory = directory
        self.expiry_in_seconds = expiry_in_days * 86400
        self.recursive = recursive
        self.delete_empty_dirs = delete_empty_dirs
        self.verbose = verbose

    def __delete_expired(self, directory):
        for file_name in os.listdir(directory):
            file_path = path.join(directory, file_name)

            size = path.getsize(file_path)

            if path.isfile(file_path):
                self.counters['total']['files'] += 1
            elif path.isdir(file_path):
                self.counters['total']['directories'] += 1
            self.counters['total']['bytes'] += size

            if path.isdir(file_path) and self.recursive:
                self.__delete_expired(file_path)
                if self.delete_empty_dirs and not os.listdir(file_path):
                    self.log('deleting empty directory: {0}'.format(file_path))
                    os.rmdir(file_path)
                    self.counters['deleted']['bytes'] += size
                    self.counters['deleted']['directories'] += 1

            if path.isfile(file_path):
                file_age = datetime.datetime.now() - datetime.datetime.fromtimestamp(path.getctime(file_path))
                file_age.total_seconds()

                if file_age.total_seconds() > self.expiry_in_seconds:
                    self.log('deleting expired file: {0}'.format(file_path))
                    os.remove(file_path)
                    self.counters['deleted']['bytes'] += size
                    self.counters['deleted']['files'] += 1

    def __size_format(self, size_in_bytes):
        size = size_in_bytes
        for unit in ['', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB', 'ZiB']:
            if abs(size) < 1024.0:
                return "%3.1f%s" % (size, unit)
            size /= 1024.0
        return "%.1f%s" % (size, 'YiB')

    def summary(self):
        print('')
        print('summary:')
        print(
            'files deleted: {0} out of {1}'.format(
                self.counters['deleted']['files'],
                self.counters['total']['files'],
            )
        )
        print(
            'directories deleted: {0} out of {1}'.format(
                self.counters['deleted']['directories'],
                self.counters['total']['directories'],
            )
        )
        print(
            'total bytes deleted: {0} out of {1}'.format(
                self.__size_format(self.counters['deleted']['bytes']),
                self.__size_format(self.counters['total']['bytes']),
            )
        )

    def run(self):
        self.log('clean up started')
        self.__delete_expired(self.directory)
        self.log('clean up finished')
        self.summary()

    def log(self, message):
        if self.verbose:
            print(message)


if __name__ == '__main__':
    if len(sys.argv) == 1:
        parser.print_help()
        exit(1)
    args = parser.parse_args()
    cleaner = BackupCleaner(args.directory, args.expiry, args.recursive, not args.leave_empty_dirs, args.v)
    cleaner.run()
    exit(0)

