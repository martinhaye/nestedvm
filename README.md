nestedvm translates C source code into Java class and jar files. It is also hard to build, with dependencies on particular versions of GCC and other tools, and a shifting array of downloads that keep going unavailable. With this image you can just run it without all the hassle. In the end you can get a jar file that runs anywhere, without the dependencies. This build is based mostly on the version from: https://github.com/tewarfel/nestedvm around Jan 18, 2016.

To build:

`docker build -t yourTagHere .`

e.g. : docker build -t mhaye/nestedvm:v5 .