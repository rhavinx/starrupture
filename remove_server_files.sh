#!/bin/bash

echo -n "Removing Server files from ${SERVERHOME}: "
if [ -d ${SERVERHOME}/StarRupture ]; then
    rm -rf ${SERVERHOME}/*
    echo "done."
else echo "failed.\n This may not be the server directory. Please manually empty it."
fi

