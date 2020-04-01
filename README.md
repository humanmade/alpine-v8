# libv8 built in Alpine Linux

This is based off the gist at https://gist.github.com/tylerchr/15a74b05944cfb90729db6a51265b6c9.

libv8 builds are uploaded to GitHub Releases in this repository. The build tar layout is:


```
/include/**
/lib/libv8.so
/lib/libchrome_zlib.so
/lib/d8
/lib/libv8_libbase.so
/lib/libv8_libplatform.so
```

> It turns out that compiling V8 for use in alpine (i.e., linked with musl) is a
real pain.

> After reading what must have been the entire contents of the Internet on the
subject (see list below) I came up with the following process that seems to do
the trick pretty cleanly.

> At the heart of this strategy are two tricks:

> 1. It turns out you actually _can_ compile GN in alpine, but only if you build
   it from the newly-split gn.googlesource.com repository rather than the Chromium
   repo.

> 2. The `depot_tools` build helpers don't seem to work in alpine, but no matter!
   This runs them in a `debian:9` container to fetch all the code, and then copies
   the results to an `alpine` container for compilation.

> After these breakthroughs it's a relatively straightforward procedure. Included in
this gist is a multi-stage Dockerfile that shows a pretty easy way to build a
musl-linked copy of V8.

## Prior Work

- https://gist.github.com/tylerchr/15a74b05944cfb90729db6a51265b6c9
- https://github.com/phpv8/v8js/issues/275
- https://github.com/AlexMasterov/dockerfiles/issues/5
- https://github.com/v8/v8/wiki/Building-from-Source
- https://bugs.chromium.org/p/v8/issues/detail?id=5701#c7
- https://github.com/JoeNyland/docker-ruby-alpine-libv8
- https://github.com/nodejs/node/blob/master/Makefile
- https://groups.google.com/forum/#!topic/v8-users/hQf8jn7BJRErco
