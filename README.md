# gleaxml

[![Package Version](https://img.shields.io/hexpm/v/gleaxml)](https://hex.pm/packages/gleaxml)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleaxml/)

gleaxml is a 100% Gleam powered XML parser !

```sh
gleam add gleaxml
```

Further documentation can be found at <https://hexdocs.pm/gleaxml>.

## Features

gleaxml doesn't fully support the XML specification yet !
However, most features are supported so it should be usable in the majority of cases.
If there is something you need that isn't supported, please open an issue [here](https://github.com/Billuc/gleaxml/issues).

Supported features:

- [x] Self-closing tags
- [x] Simple tags
- [x] Simple text
- [x] References
- [x] CDATA
- [x] Comments
- [ ] Document type definitions
- [ ] Processing instructions
- [ ] Entity declarations
- [ ] Parsed entities
- [ ] Element type declarations
- [ ] Attribute list declarations
- [ ] Conditional sections
- [ ] Notation declarations

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
