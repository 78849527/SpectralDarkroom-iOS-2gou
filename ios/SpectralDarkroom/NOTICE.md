Spectral Darkroom is an unofficial iOS prototype adapted from SpektraLab
(https://github.com/JamesQiu2005/SpektraLab) by Hanze Qiu.
It is not endorsed by the SpektraLab project and does not use its name or icon.

The application and C++/Metal engine are GPL-3.0-or-later.
Film and print profiles and print LUTs derive from Andrea Volpato's
spektrafilm project (https://github.com/andreavolpato/spektrafilm)
and are licensed CC BY-SA 4.0
(https://creativecommons.org/licenses/by-sa/4.0/).
The bundled metal-cpp headers are Apache-2.0
(https://www.apache.org/licenses/LICENSE-2.0).
For license texts and attribution, consult this repository's LICENSE.txt,
engine/third_party/metal-cpp/LICENSE.txt, and README.md, as well as the
upstream repositories linked above.

The iOS build caps imported images at a 4096-pixel long edge; it does not
yet offer the desktop application's complete editing workflow or color
management controls.
