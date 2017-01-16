<p align="center">
    <img src="logo.png" width="300" max-width="50%" alt=“Files” />
</p>

Welcome to **Files**, a compact library that provides a nicer way to handle *files* and *folders*  in Swift. It’s primarily aimed at Swift scripting and tooling, but can also be embedded in applications that need to access the file system. It's essentially a thin wrapper around the `FileManager` APIs that `Foundation` provides.

### Features

- [X] Modern, object-oriented API for accessing, reading and writing files & folders.
- [X] Unified, simple `do, try, catch` error handling.
- [X] Easily construct recursive and flat sequences of files and folders.

### Examples

Easily iterate over the files contained in a folder
```swift
for file in try Folder(path: "MyFolder") {
    print(file.name)
}
```
