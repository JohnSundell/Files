<p align="center">
    <img src="logo.png" width="300" max-width="50%" alt=“Files” />
</p>

<p align="center">
    <a href="https://cocoapods.org/pods/Unbox">
        <img src="https://img.shields.io/cocoapods/v/Files.svg" alt="CocoaPods" />
    </a>
    <a href="https://github.com/Carthage/Carthage">
        <img src="https://img.shields.io/badge/carthage-compatible-4BC51D.svg?style=flat" alt="Carthage" />
    </a>
    <a href="https://twitter.com/johnsundell">
        <img src="https://img.shields.io/badge/contact-@johnsundell-blue.svg?style=flat" alt="Twitter: @johnsundell" />
    </a>
</p>

Welcome to **Files**, a compact library that provides a nicer way to handle *files* and *folders*  in Swift. It’s primarily aimed at Swift scripting and tooling, but can also be embedded in applications that need to access the file system. It's essentially a thin wrapper around the `FileManager` APIs that `Foundation` provides.

## Features

- [X] Modern, object-oriented API for accessing, reading and writing files & folders.
- [X] Unified, simple `do, try, catch` error handling.
- [X] Easily construct recursive and flat sequences of files and folders.

## Examples

Iterate over the files contained in a folder:
```swift
for file in try Folder(path: "MyFolder").files {
    print(file.name)
}
```

Rename all files contained in a folder:
```swift
try Folder(path: "MyFolder").files.enumerated().forEach { (index, file) in
    try file.rename(to: file.nameWithoutExtension + "\(index)")
}
```

Recursively iterate over all folders in a tree:
```swift
FileSystem().homeFolder.makeSubfolderSequence(recursive: true).forEach { file in
    print("Name : \(file.name), parent: \(file.parent)")
}
```

Create, write and delete files and folders:
```swift
let folder = try Folder(path: "/users/john/folder")
let file = try folder.createFile(named: "file.json")
try file.write(data: wrap(object))
try file.delete()
try folder.delete()
```

Move all files in a folder to another:
```swift
let originFolder = try Folder(path: "/users/john/folderA")
let targetFolder = try Folder(path: "/users/john/folderB")
try originFolder.files.move(to: targetFolder)
```

## Usage

Files can be easily used in both a Swift script, command line tool or in an app for iOS, macOS or tvOS.

### In a script

- Write a Swift script in your favorite editor.
- Concat your script with `Files.swift` and run it using `swift` (for example: `$ cat files.swift myScript.swift | swift -`).

### In a command line tool

- Drag the file `Files.swift` into your command line tool's Xcode project.

### In an application

Either

- Drag the file `Files.swift` into your application's Xcode project.

or

- Use CocoaPods, Carthage or the Swift Package manager to include Files as a dependency in your project.
