# OpenBLASBuilder

A builder of OpenBLAS.

## Installation

To use `OpenBLASBuilder`, describe the following `deps` in `mix.exs`.

```elixir
def deps do
  [
    {:openblas_builder, "~> 0.1.0-dev", github: "zeam-vm/openblas_builder", branch: "main"}
  ]
end
```

## License

Note that the build artifacts are a result of compiling Google XLA, hence are under their own license. See [OpenBLAS](https://github.com/xianyi/OpenBLAS).

Copyright (c) 2022 University of Kitakyushu

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
