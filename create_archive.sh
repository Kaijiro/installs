#!/bin/sh

tar -czf transfert_archive.tar.Z -C ~/ \
                                .aws \
                                .ssh \
                                .gitconfig \
                                .npmrc \
                                .yarnrc.yml
