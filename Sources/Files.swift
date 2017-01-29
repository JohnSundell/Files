/**
 *  Files
 *
 *  Copyright (c) 2017 John Sundell. Licensed under the MIT license, as follows:
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in all
 *  copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 *  SOFTWARE.
 */

import Foundation

// MARK: - Public API

/**
 *  Class that represents a file system
 *
 *  You only have to interact with this class in case you want to get a reference
 *  to a system folder (like the temporary cache folder, or the user's home folder).
 *
 *  To open other files & folders, use the `File` and `Folder` class respectively.
 */
public class FileSystem {
    private let fileManager: FileManager

    /**
     *  Class that represents an item that's stored by a file system
     *
     *  This is an abstract base class, that has two publically initializable concrete
     *  implementations, `File` and `Folder`. You can use the APIs available on this class
     *  to perform operations that are supported by both files & folders.
     */
    public class Item: Equatable, CustomStringConvertible {
        /// Errror type used for invalid paths for files or folders
        public enum PathError: Error, Equatable, CustomStringConvertible {
            /// Thrown when an empty path was given when initializing a file
            case empty
            /// Thrown when an item of the expected type wasn't found for a given path (contains the path)
            case invalid(String)
        
            /// Operator used to compare two instances for equality
            public static func ==(lhs: PathError, rhs: PathError) -> Bool {
                switch lhs {
                case .empty:
                    switch rhs {
                    case .empty:
                        return true
                    case .invalid(_):
                        return false
                    }
                case .invalid(let pathA):
                    switch rhs {
                    case .empty:
                        return false
                    case .invalid(let pathB):
                        return pathA == pathB
                    }
                }
            }
        
            /// A string describing the error
            public var description: String {
                switch self {
                case .empty:
                    return "Empty path given"
                case .invalid(let path):
                    return "Invalid path given: \(path)"
                }
            }
        }
        
        /// Error type used for failed operations run on files or folders
        public enum OperationError: Error, Equatable {
            /// Thrown when a file or folder couldn't be renamed (contains the item)
            case renameFailed(Item)
            /// Thrown when a file or folder couldn't be moved (contains the item)
            case moveFailed(Item)
            /// Thrown when a file or folder couldn't be deleted (contains the item)
            case deleteFailed(Item)
            
            /// Operator used to compare two instances for equality
            public static func ==(lhs: OperationError, rhs: OperationError) -> Bool {
                switch lhs {
                case .renameFailed(let itemA):
                    switch rhs {
                    case .renameFailed(let itemB):
                        return itemA == itemB
                    case .moveFailed(_):
                        return false
                    case .deleteFailed(_):
                        return false
                    }
                case .moveFailed(let itemA):
                    switch rhs {
                    case .renameFailed(_):
                        return false
                    case .moveFailed(let itemB):
                        return itemA == itemB
                    case .deleteFailed(_):
                        return false
                    }
                case .deleteFailed(let itemA):
                    switch rhs {
                    case .renameFailed(_):
                        return false
                    case .moveFailed(_):
                        return false
                    case .deleteFailed(let itemB):
                        return itemA == itemB
                    }
                }
            }
        }
        
        /// Operator used to compare two instances for equality
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            guard lhs.kind == rhs.kind else {
                return false
            }
            
            return lhs.path == rhs.path
        }
        
        /// The path of the item, relative to the root of the file system
        public private(set) var path: String
        
        /// The name of the item (including any extension)
        public private(set) var name: String
        
        /// The name of the item (excluding any extension)
        public var nameExcludingExtension: String {
            guard let `extension` = `extension` else {
                return name
            }
            
            let startIndex = name.index(name.endIndex, offsetBy: -`extension`.characters.count - 1)
            return name.replacingCharacters(in: startIndex..<name.endIndex, with: "")
        }
        
        /// Any extension that the item has
        public var `extension`: String? {
            let components = name.components(separatedBy: ".")
            
            guard components.count > 1 else {
                return nil
            }
            
            return components.last
        }
        
        /// The folder that the item is contained in, or `nil` if this item is the root folder of the file system
        public var parent: Folder? {
            guard path != "/" else {
                return nil
            }
            
            var pathComponents = path.pathComponents
            
            switch kind {
            case .file:
                pathComponents.removeLast()
            case .folder:
                pathComponents.removeLast(2)
            }
            
            return try? Folder(path: pathComponents.joined(separator: "/"), using: fileManager)
        }
        
        /// A string describing the item
        public var description: String {
            return "\(kind)(name: \(name), path: \(path))"
        }
        
        fileprivate let kind: Kind
        fileprivate let fileManager: FileManager
        
        fileprivate init(path: String, kind: Kind, using fileManager: FileManager) throws {
            guard !path.isEmpty else {
                throw PathError.empty
            }
            
            guard fileManager.itemKind(atPath: path) == kind else {
                throw PathError.invalid(path)
            }
            
            self.path = path
            self.fileManager = fileManager
            self.kind = kind
            
            let pathComponents = path.pathComponents
            
            switch kind {
            case .file:
                self.name = pathComponents.last!
            case .folder:
                self.name = pathComponents[pathComponents.count - 2]
            }
        }
        
        /**
         *  Rename the item
         *
         *  - parameter newName: The new name that the item should have
         *  - parameter keepExtension: Whether the file should keep the same extension as it had before (defaults to `true`)
         *
         *  - throws: `FileSystem.Item.OperationError.renameFailed` if the item couldn't be renamed
         */
        public func rename(to newName: String, keepExtension: Bool = true) throws {
            guard let parent = parent else {
                throw OperationError.renameFailed(self)
            }
            
            var newName = newName
            
            if keepExtension {
                if let `extension` = `extension` {
                    let extensionString = ".\(`extension`)"
                    
                    if !newName.hasSuffix(extensionString) {
                        newName += extensionString
                    }
                }
            }
            
            var newPath = parent.path + newName
            
            if kind == .folder && !newPath.hasSuffix("/") {
                newPath += "/"
            }
            
            do {
                try fileManager.moveItem(atPath: path, toPath: newPath)
                
                name = newName
                path = newPath
            } catch {
                throw OperationError.renameFailed(self)
            }
        }
        
        /**
         *  Move this item to a new folder
         *
         *  - parameter newParent: The new parent folder that the item should be moved to
         *
         *  - throws: `FileSystem.Item.OperationError.moveFailed` if the item couldn't be moved
         */
        public func move(to newParent: Folder) throws {
            let newPath = newParent.path + name
            
            do {
                try fileManager.moveItem(atPath: path, toPath: newPath)
                path = newPath
            } catch {
                throw OperationError.moveFailed(self)
            }
        }
        
        /**
         *  Delete the item from disk
         *
         *  The item will be immediately deleted. If this is a folder, all of its contents will also be deleted.
         *
         *  - throws: `FileSystem.Item.OperationError.deleteFailed` if the item coudn't be deleted
         */
        public func delete() throws {
            do {
                try fileManager.removeItem(atPath: path)
            } catch {
                throw OperationError.deleteFailed(self)
            }
        }
    }
    
    /// A reference to the temporary folder used by this file system
    public var temporaryFolder: Folder {
        return try! Folder(path: NSTemporaryDirectory(), using: fileManager)
    }
    
    /// A reference to the current user's home folder
    public var homeFolder: Folder {
        let path = ProcessInfo.processInfo.environment["HOME"]!
        return try! Folder(path: path, using: fileManager)
    }
    
    /**
     *  Initialize an instance of this class
     *
     *  - parameter fileManager: Optionally give a custom file manager to use to perform operations
     */
    public init(using fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
}

/**
 *  Class representing a file that's stored by a file system
 *
 *  You initialize this class with a path, or by asking a folder to return a file for a given name
 */
public final class File: FileSystem.Item, FileSystemIterable {
    /// Error type specific to file-related operations
    public enum Error: Swift.Error {
        /// Thrown when a file couldn't be written to
        case writeFailed
        /// Thrown when a file couldn't be read, either because it was malformed or because it has been deleted
        case readFailed
    }
    
    /**
     *  Initialize an instance of this class with a path pointing to a file
     *
     *  - parameter path: The path of the file to create a representation of
     *  - parameter fileManager: Optionally give a custom file manager to use to look up the file
     *
     *  - throws: `FileSystemItem.Error` in case an empty path was given, or if the path given doesn't
     *    point to a readable file.
     */
    public init(path: String, using fileManager: FileManager = .default) throws {
        try super.init(path: path, kind: .file, using: fileManager)
    }
    
    /**
     *  Read the data contained within this file
     *
     *  - throws: `File.Error.readFailed` if the file's data couldn't be read
     */
    public func read() throws -> Data {
        do {
            return try Data(contentsOf: path.fileURL)
        } catch {
            throw Error.readFailed
        }
    }
    
    /**
     *  Write data to the file, replacing its current content
     *
     *  - parameter data: The data to write to the file
     *
     *  - throws: `File.Error.writeFailed` if the file couldn't be written to
     */
    public func write(data: Data) throws {
        do {
            try data.write(to: path.fileURL)
        } catch {
            throw Error.writeFailed
        }
    }
    
    /**
     *  Write a string to the file, replacing its current content
     *
     *  - parameter string: The string to write to the file
     *  - parameter encoding: Optionally give which encoding that the string should be encoded in (defaults to UTF-8)
     *
     *  - throws: `File.Error.writeFailed` if the string couldn't be encoded, or written to the file
     */
    public func write(string: String, encoding: String.Encoding = .utf8) throws {
        guard let data = string.data(using: encoding) else {
            throw Error.writeFailed
        }
        
        try write(data: data)
    }
}

/**
 *  Class representing a folder that's stored by a file system
 *
 *  You initialize this class with a path, or by asking a folder to return a subfolder for a given name
 */
public final class Folder: FileSystem.Item, FileSystemIterable {
    /// Error type specific to folder-related operations
    public enum Error: Swift.Error {
        /// Thrown when a subfolder couldn't be created
        case creatingSubfolderFailed
    }
    
    /// The sequence of files that are contained within this folder (non-recursive)
    public var files: FileSystemSequence<File> {
        return makeFileSequence()
    }
    
    /// The sequence of folders that are subfolers of this folder (non-recursive)
    public var subfolders: FileSystemSequence<Folder> {
        return makeSubfolderSequence()
    }
    
    /**
     *  Initialize an instance of this class with a path pointing to a folder
     *
     *  - parameter path: The path of the folder to create a representation of
     *  - parameter fileManager: Optionally give a custom file manager to use to look up the folder
     *
     *  - throws: `FileSystemItem.Error` in case an empty path was given, or if the path given doesn't
     *    point to a readable folder.
     */
    public init(path: String, using fileManager: FileManager = .default) throws {
        var path = path
        
        if path.isEmpty {
            path = fileManager.currentDirectoryPath
        } else if !path.hasSuffix("/") {
            path += "/"
        }
        
        try super.init(path: path, kind: .folder, using: fileManager)
    }
    
    /**
     *  Return a file with a given name that is contained in this folder
     *
     *  - parameter fileName: The name of the file to return
     *
     *  - throws: `File.PathError.invalid` if the file couldn't be found
     */
    public func file(named fileName: String) throws -> File {
        return try File(path: path + fileName, using: fileManager)
    }
    
    /**
     *  Return a folder with a given name that is contained in this folder
     *
     *  - parameter folderName: The name of the folder to return
     *
     *  - throws: `Folder.PathError.invalid` if the folder couldn't be found
     */
    public func subfolder(named folderName: String) throws -> Folder {
        return try Folder(path: path + folderName, using: fileManager)
    }
    
    /**
     *  Create a file in this folder and return it
     *
     *  - parameter fileName: The name of the file to create
     *  - parameter data: Optionally give any data that the file should contain
     *
     *  - throws: `File.Error.writeFailed` if the file couldn't be created
     *
     *  - returns: The file that was created
     */
    @discardableResult public func createFile(named fileName: String, contents data: Data = .init()) throws -> File {
        let filePath = path + fileName
        
        guard fileManager.createFile(atPath: filePath, contents: data, attributes: nil) else {
            throw File.Error.writeFailed
        }
        
        return try File(path: filePath, using: fileManager)
    }
    
    /**
     *  Create a subfolder of this folder and return it
     *
     *  - parameter folderName: The name of the folder to create
     *
     *  - throws: `Folder.Error.creatingSubfolderFailed` if the subfolder couldn't be created
     *
     *  - returns: The folder that was created
     */
    @discardableResult public func createSubfolder(named folderName: String) throws -> Folder {
        let subfolderPath = path + folderName
        
        do {
            try fileManager.createDirectory(atPath: subfolderPath, withIntermediateDirectories: false, attributes: nil)
            return try Folder(path: subfolderPath, using: fileManager)
        } catch {
            throw Error.creatingSubfolderFailed
        }
    }
    
    /**
     *  Create a sequence containing the files that are contained within this folder
     *
     *  - parameter recursive: Whether the files contained in all subfolders of this folder should also be included
     *  - parameter includeHidden: Whether hidden (dot) files should be included in the sequence (default: false)
     *
     *  If `recursive = true` the folder tree will be traversed breath-first
     */
    public func makeFileSequence(recursive: Bool = false, includeHidden: Bool = false) -> FileSystemSequence<File> {
        return FileSystemSequence(path: path, recursive: recursive, includeHidden: includeHidden, using: fileManager)
    }
    
    /**
     *  Create a sequence containing the folders that are subfolders of this folder
     *
     *  - parameter recursive: Whether the entire folder tree contained under this folder should also be included
     *  - parameter includeHidden: Whether hidden (dot) files should be included in the sequence (default: false)
     *
     *  If `recursive = true` the folder tree will be traversed breath-first
     */
    public func makeSubfolderSequence(recursive: Bool = false, includeHidden: Bool = false) -> FileSystemSequence<Folder> {
        return FileSystemSequence(path: path, recursive: recursive, includeHidden: includeHidden, using: fileManager)
    }
    
    /**
     *  Empty this folder, removing all of its content
     *
     *  This will still keep the folder itself on disk. If you wish to delete the folder as well, call `delete()` on it.
     */
    public func empty() throws {
        try files.forEach { try $0.delete() }
        try subfolders.forEach { try $0.delete() }
    }
}

/// Protocol adopted by file system tyeps that may be iterated over (this protocol is an implementation detail)
public protocol FileSystemIterable {
    /// Initialize an instance with a path and a file manager
    init(path: String, using fileManager: FileManager) throws
}

/**
 *  A sequence used to iterate over file system items
 *
 *  You don't create instances of this class yourself. Instead, you can access various sequences on a `Folder`, for example
 *  containing its files and subfolders. The sequence is lazily evaluated when you perform operations on it.
 */
public class FileSystemSequence<T: FileSystem.Item>: Sequence where T: FileSystemIterable {
    /// The number of items contained in this sequence. Accessing this causes the sequence to be evaluated.
    public var count: Int {
        var count = 0
        forEach { _ in count += 1 }
        return count
    }
    
    /// An array containing the names of all the items contained in this sequence. Accessing this causes the sequence to be evaluated.
    public var names: [String] {
        return map { $0.name }
    }
    
    /// The first item of the sequence. Accessing this causes the sequence to be evaluated until an item is found
    public var first: T? {
        return makeIterator().next()
    }
    
    /// The last item of the sequence. Accessing this causes the sequence to be evaluated.
    public var last: T? {
        var item: T?
        forEach { item = $0 }
        return item
    }
    
    private let path: String
    private let recursive: Bool
    private let includeHidden: Bool
    private let fileManager: FileManager
    
    fileprivate init(path: String, recursive: Bool, includeHidden: Bool, using fileManager: FileManager) {
        self.path = path
        self.recursive = recursive
        self.includeHidden = includeHidden
        self.fileManager = fileManager
    }
    
    /// Create an iterator to use to iterate over the sequence
    public func makeIterator() -> FileSystemIterator<T> {
        return FileSystemIterator(path: path, recursive: recursive, includeHidden: includeHidden, using: fileManager)
    }
    
    /// Move all the items in this sequence to a new folder. See `FileSystem.Item.move(to:)` for more info.
    public func move(to newParent: Folder) throws {
        try forEach { try $0.move(to: newParent) }
    }
}

/// Iterator used to iterate over an instance of `FileSystemSequence`
public class FileSystemIterator<T: FileSystem.Item>: IteratorProtocol where T: FileSystemIterable {
    private let path: String
    private let recursive: Bool
    private let includeHidden: Bool
    private let fileManager: FileManager
    private var itemNames: [String]
    private lazy var childIteratorQueue = [FileSystemIterator]()
    private var currentChildIterator: FileSystemIterator?
    
    fileprivate init(path: String, recursive: Bool, includeHidden: Bool, using fileManager: FileManager) {
        self.path = path
        self.recursive = recursive
        self.includeHidden = includeHidden
        self.fileManager = fileManager
        self.itemNames = fileManager.itemNames(inFolderAtPath: path)
    }
    
    /// Advance the iterator to the next element
    public func next() -> T? {
        if itemNames.isEmpty {
            if let childIterator = currentChildIterator {
                if let next = childIterator.next() {
                    return next
                }
            }
            
            guard !childIteratorQueue.isEmpty else {
                return nil
            }
            
            currentChildIterator = childIteratorQueue.removeFirst()
            return next()
        }
        
        let nextItemName = itemNames.removeFirst()
        
        guard includeHidden || !nextItemName.hasPrefix(".") else {
            return next()
        }
        
        let nextItemPath = path + nextItemName
        let nextItem = try? T(path: nextItemPath, using: fileManager)
        
        if recursive && nextItem?.kind != .file {
            let childPath = nextItemPath + "/"
            let child = FileSystemIterator(path: childPath, recursive: true, includeHidden: includeHidden, using: fileManager)
            childIteratorQueue.append(child)
        }
        
        return nextItem ?? next()
    }
}

// MARK: - Private

private extension FileSystem.Item {
    enum Kind: CustomStringConvertible {
        case file
        case folder
        
        var description: String {
            switch self {
            case .file:
                return "File"
            case .folder:
                return "Folder"
            }
        }
    }
}

private extension FileManager {
    func itemKind(atPath path: String) -> FileSystem.Item.Kind? {
        var objCBool: ObjCBool = false
        
        guard fileExists(atPath: path, isDirectory: &objCBool) else {
            return nil
        }
        
        if Bool(objCBool) {
            return .folder
        }
        
        return .file
    }
    
    func itemNames(inFolderAtPath path: String) -> [String] {
        do {
            return try contentsOfDirectory(atPath: path)
        } catch {
            return []
        }
    }
}

private extension String {
    var fileURL: URL {
        return URL(string: "file://" + self)!
    }
    
    var pathComponents: [String] {
        return components(separatedBy: "/")
    }
}
