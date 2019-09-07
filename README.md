<p align="center">
    <img src="logo.png" width="300" max-width="50%" alt=“Files” />
</p>

<p align="center">
    <a href="https://dashboard.buddybuild.com/apps/5932f7d9b0c2b000015d6b79/build/latest?branch=master">
        <img src="https://dashboard.buddybuild.com/api/statusImage?appID=5932f7d9b0c2b000015d6b79&branch=master&build=latest" alt="BuddyBuild" />
    </a>
    <img src="https://img.shields.io/badge/Swift-5.0-orange.svg" />
    <a href="https://cocoapods.org/pods/Files">
        <img src="https://img.shields.io/cocoapods/v/Files.svg" alt="CocoaPods" />
    </a>
    <a href="https://github.com/Carthage/Carthage">
        <img src="https://img.shields.io/badge/carthage-compatible-4BC51D.svg?style=flat" alt="Carthage" />
    </a>
    <a href="https://swift.org/package-manager">
        <img src="https://img.shields.io/badge/spm-compatible-brightgreen.svg?style=flat" alt="Swift Package Manager" />
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
Folder.home.subfolders.recrusive.forEach { folder in
    print("Name : \(folder.name), parent: \(folder.parent)")
}
```

Create, write and delete files and folders:

```swift
let folder = try Folder(path: "/users/john/folder")
let file = try folder.createFile(named: "file.json")
try file.write(string: "{\"hello\": \"world\"}")
try file.delete()
try folder.delete()
```

Move all files in a folder to another:

```swift
let originFolder = try Folder(path: "/users/john/folderA")
let targetFolder = try Folder(path: "/users/john/folderB")
try originFolder.files.move(to: targetFolder)
```

Easy access to system folders:

```swift
Folder.current
Folder.root
Folder.library
Folder.temporary
Folder.home
Folder.documents
```

## Installation

Files can be easily used in either a Swift script, a command line tool, or in an app for iOS, macOS, tvOS or Linux.

### Using the Swift Package Manager (preferred)

To install Files for use in a Swift Package Manager-powered tool, script or server-side application, add Files as a dependency to your `Package.swift` file. For more information, please see the [Swift Package Manager documentation](https://github.com/apple/swift-package-manager/tree/master/Documentation).

```swift
.package(url: "https://github.com/JohnSundell/Files", from: "4.0.0")
```

### Using CocoaPods or Carthage

Please refer to [CocoaPods’](https://cocoapods.org) or [Carthage’s](https://github.com/Carthage/Carthage) own documentation for instructions on how to add dependencies using those tools.

### As a file

Since all of Files is implemented within a single file, you can easily use it in any project by simply dragging the file `Files.swift` into your Xcode project.

## Backstory

So, why was this made? As I've migrated most of my build tools and other scripts from languages like Bash, Ruby and Python to Swift, I've found myself lacking an easy way to deal with the file system. Sure, `FileManager` has a quite nice API, but it can be quite cumbersome to use because of its string-based nature, which makes simple scripts that move or rename files quickly become quite complex.

So, I made **Files**, to enable me to quickly handle files and folders, in an expressive way. And, since I love open source, I thought - why not package it up and share it with the community? :)

## Questions or feedback?

Feel free to [open an issue](https://github.com/JohnSundell/Files/issues/new), or find me [@johnsundell on Twitter](https://twitter.com/johnsundell).
