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
    fileprivate let fileManager: FileManager

    /**
     *  Class that represents an item that's stored by a file system
     *
     *  This is an abstract base class, that has two publically initializable concrete
     *  implementations, `File` and `Folder`. You can use the APIs available on this class
     *  to perform operations that are supported by both files & folders.
     */
    public class Item: Equatable, CustomStringConvertible {
        #if os(macOS)
        /// The attributes of the `FileSystem.Item` on mac os platform.
        public typealias Attributes = [FileAttributeKey: Any]
        #endif
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
        public enum OperationError: Error, Equatable, CustomStringConvertible {
            /// Thrown when a file or folder couldn't be renamed (contains the item)
            case renameFailed(Item)
            /// Thrown when a file or folder couldn't be moved (contains the item)
            case moveFailed(Item)
            /// Thrown when a file or folder couldn't be copied (contains the item)
            case copyFailed(Item)
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
                    case .copyFailed(_):
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
                    case .copyFailed(_):
                        return false
                    case .deleteFailed(_):
                        return false
                    }
                case .copyFailed(let itemA):
                    switch rhs {
                    case .renameFailed(_):
                        return false
                    case .moveFailed(_):
                        return false
                    case .copyFailed(let itemB):
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
                    case .copyFailed(_):
                        return false
                    case .deleteFailed(let itemB):
                        return itemA == itemB
                    }
                }
            }

            /// A string describing the error
            public var description: String {
                switch self {
                case .renameFailed(let item):
                    return "Failed to rename item: \(item)"
                case .moveFailed(let item):
                    return "Failed to move item: \(item)"
                case .copyFailed(let item):
                    return "Failed to copy item: \(item)"
                case .deleteFailed(let item):
                    return "Failed to delete item: \(item)"
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

            let endIndex = name.index(name.endIndex, offsetBy: -`extension`.count - 1)
            return String(name[..<endIndex])
        }
        
        /// Any extension that the item has
        public var `extension`: String? {
            let components = name.components(separatedBy: ".")
            
            guard components.count > 1 else {
                return nil
            }
            
            return components.last
        }

        /// The date when the item was last modified
        public private(set) lazy var modificationDate: Date = self.loadModificationDate()

        /// The folder that the item is contained in, or `nil` if this item is the root folder of the file system
        public var parent: Folder? {
            return fileManager.parentPath(for: path).flatMap { parentPath in
                return try? Folder(path: parentPath, using: fileManager)
            }
        }
        
        /// A string describing the item
        public var description: String {
            return "\(kind)(name: \(name), path: \(path))"
        }
        
        fileprivate let kind: Kind
        fileprivate let fileManager: FileManager
      
        #if os(macOS)
        /// The file attributes of the item on file system.
        @available(macOS 10.5, *)
        public var attributes: Attributes? {
            get {
                return try? fileManager.attributesOfItem(atPath: path)
            }
          
            set {
                try? fileManager.setAttributes(newValue ?? [:], ofItemAtPath: path)
            }
        }
        #endif
      
        fileprivate init(path: String, kind: Kind, using fileManager: FileManager) throws {
            guard !path.isEmpty else {
                throw PathError.empty
            }
            
            let path = try fileManager.absolutePath(for: path)
            
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
            var newPath = newParent.path + name

            if kind == .folder && !newPath.hasSuffix("/") {
                newPath += "/"
            }

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
        return try! Folder(path: ProcessInfo.processInfo.homeFolderPath, using: fileManager)
    }

    // A reference to the folder that is the current working directory
    public var currentFolder: Folder {
        return try! Folder(path: "")
    }
    
    /**
     *  Initialize an instance of this class
     *
     *  - parameter fileManager: Optionally give a custom file manager to use to perform operations
     */
    public init(using fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /**
     *  Create a new file at a given path
     *
     *  - parameter path: The path at which a file should be created. If the path is missing intermediate
     *                    parent folders, those will be created as well.
     *
     *  - throws: `File.Error.writeFailed`
     *
     *  - returns: The file that was created
     */
    @discardableResult public func createFile(at path: String, contents: Data = Data()) throws -> File {
        let path = try fileManager.absolutePath(for: path)

        guard let parentPath = fileManager.parentPath(for: path) else {
            throw File.Error.writeFailed
        }

        do {
            let index = path.index(path.startIndex, offsetBy: parentPath.count + 1)
            let name = String(path[index...])
            return try createFolder(at: parentPath).createFile(named: name, contents: contents)
        } catch {
            throw File.Error.writeFailed
        }
    }

    /**
     *  Either return an existing file, or create a new one, at a given path.
     *
     *  - parameter path: The path for which a file should either be returned or created at. If the folder
     *                    is missing, any intermediate parent folders will also be created.
     *
     *  - throws: `File.Error.writeFailed`
     *
     *  - returns: The file that was either created or found.
     */
    @discardableResult public func createFileIfNeeded(at path: String, contents: Data = Data()) throws -> File {
        if let existingFile = try? File(path: path, using: fileManager) {
            return existingFile
        }

        return try createFile(at: path, contents: contents)
    }

    /**
     *  Create a new folder at a given path
     *
     *  - parameter path: The path at which a folder should be created. If the path is missing intermediate
     *                    parent folders, those will be created as well.
     *
     *  - throws: `Folder.Error.creatingFolderFailed`
     *
     *  - returns: The folder that was created
     */
    @discardableResult public func createFolder(at path: String) throws -> Folder {
        do {
            let path = try fileManager.absolutePath(for: path)
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            return try Folder(path: path, using: fileManager)
        } catch {
            throw Folder.Error.creatingFolderFailed
        }
    }

    /**
     *  Either return an existing folder, or create a new one, at a given path
     *
     *  - parameter path: The path for which a folder should either be returned or created at. If the folder
     *                    is missing, any intermediate parent folders will also be created.
     *
     *  - throws: `Folder.Error.creatingFolderFailed`
     */
    @discardableResult public func createFolderIfNeeded(at path: String) throws -> Folder {
        if let existingFolder = try? Folder(path: path, using: fileManager) {
            return existingFolder
        }

        return try createFolder(at: path)
    }
}

/**
 *  Class representing a file that's stored by a file system
 *
 *  You initialize this class with a path, or by asking a folder to return a file for a given name
 */
public final class File: FileSystem.Item, FileSystemIterable {
    /// Error type specific to file-related operations
    public enum Error: Swift.Error, CustomStringConvertible {
        /// Thrown when a file couldn't be written to
        case writeFailed
        /// Thrown when a file couldn't be read, either because it was malformed or because it has been deleted
        case readFailed

        /// A string describing the error
        public var description: String {
            switch self {
            case .writeFailed:
                return "Failed to write to file"
            case .readFailed:
                return "Failed to read file"
            }
        }
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
            return try Data(contentsOf: URL(fileURLWithPath: path))
        } catch {
            throw Error.readFailed
        }
    }

    /**
     *  Read the data contained within this file, and convert it to a string
     *
     *  - throws: `File.Error.readFailed` if the file's data couldn't be read as a string
     */
    public func readAsString(encoding: String.Encoding = .utf8) throws -> String {
        guard let string = try String(data: read(), encoding: encoding) else {
            throw Error.readFailed
        }

        return string
    }

    /**
     *  Read the data contained within this file, and convert it to an int
     *
     *  - throws: `File.Error.readFailed` if the file's data couldn't be read as an int
     */
    public func readAsInt() throws -> Int {
        guard let int = try Int(readAsString()) else {
            throw Error.readFailed
        }

        return int
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
            try data.write(to: URL(fileURLWithPath: path))
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

    /**
     *  Append data to the end of the file
     *
     *  - parameter data: The data to append to the file
     *
     *  - throws: `File.Error.writeFailed` if the file couldn't be written to
     */
    public func append(data: Data) throws {
        do {
            let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: path))
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        } catch {
            throw Error.writeFailed
        }
    }

    /**
     *  Append a string to the end of the file
     *
     *  - parameter string: The string to append to the file
     *  - parameter encoding: Optionally give which encoding that the string should be encoded in (defaults to UTF-8)
     *
     *  - throws: `File.Error.writeFailed` if the string couldn't be encoded, or written to the file
     */
    public func append(string: String, encoding: String.Encoding = .utf8) throws {
        guard let data = string.data(using: encoding) else {
            throw Error.writeFailed
        }

        try append(data: data)
    }
    
    /**
     *  Copy this file to a new folder
     *
     *  - parameter folder: The folder that the file should be copy to
     *
     *  - throws: `FileSystem.Item.OperationError.copyFailed` if the file couldn't be copied
     */
    @discardableResult public func copy(to folder: Folder) throws -> File {
        let newPath = folder.path + name
        
        do {
            try fileManager.copyItem(atPath: path, toPath: newPath)
            return try File(path: newPath)
        } catch {
            throw OperationError.copyFailed(self)
        }
    }
}

/**
 *  Class representing a folder that's stored by a file system
 *
 *  You initialize this class with a path, or by asking a folder to return a subfolder for a given name
 */
public final class Folder: FileSystem.Item, FileSystemIterable {
    /// Error type specific to folder-related operations
    public enum Error: Swift.Error, CustomStringConvertible {
        /// Thrown when a folder couldn't be created
        case creatingFolderFailed

        @available(*, deprecated: 1.4.0, renamed: "creatingFolderFailed")
        case creatingSubfolderFailed

        /// A string describing the error
        public var description: String {
            switch self {
            case .creatingFolderFailed:
                return "Failed to create folder"
            case .creatingSubfolderFailed:
                return "Failed to create subfolder"
            }
        }
    }
    
    /// The sequence of files that are contained within this folder (non-recursive)
    public var files: FileSystemSequence<File> {
        return makeFileSequence()
    }
    
    /// The sequence of folders that are subfolers of this folder (non-recursive)
    public var subfolders: FileSystemSequence<Folder> {
        return makeSubfolderSequence()
    }

    /// A reference to the folder that is the current working directory
    public static var current: Folder {
        return FileSystem(using: .default).currentFolder
    }

    /// A reference to the current user's home folder
    public static var home: Folder {
        return FileSystem(using: .default).homeFolder
    }

    /// A reference to the temporary folder used by this file system
    public static var temporary: Folder {
        return FileSystem(using: .default).temporaryFolder
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
        }

        if !path.hasSuffix("/") {
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
     *  Return a file at a given path that is contained in this folder's tree
     *
     *  - parameter filePath: The subpath of the file to return. Relative to this folder.
     *
     *  - throws: `File.PathError.invalid` if the file couldn't be found
     */
    public func file(atPath filePath: String) throws -> File {
        return try File(path: path + filePath, using: fileManager)
    }

    /**
     *  Return whether this folder contains a file with a given name
     *
     *  - parameter fileName: The name of the file to check for
     */
    public func containsFile(named fileName: String) -> Bool {
        return (try? file(named: fileName)) != nil
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
     *  Return a folder at a given path that is contained in this folder's tree
     *
     *  - parameter folderPath: The subpath of the folder to return. Relative to this folder.
     *
     *  - throws: `Folder.PathError.invalid` if the folder couldn't be found
     */
    public func subfolder(atPath folderPath: String) throws -> Folder {
        return try Folder(path: path + folderPath, using: fileManager)
    }

    /**
     *  Return whether this folder contains a subfolder with a given name
     *
     *  - parameter folderName: The name of the folder to check for
     */
    public func containsSubfolder(named folderName: String) -> Bool {
        return (try? subfolder(named: folderName)) != nil
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
     *  Create a file in this folder and return it
     *
     *  - parameter fileName: The name of the file to create
     *  - parameter contents: The string content that the file should contain
     *  - parameter encoding: The encoding that the given string content should be encoded with
     *
     *  - throws: `File.Error.writeFailed` if the file couldn't be created
     *
     *  - returns: The file that was created
     */
    @discardableResult public func createFile(named fileName: String, contents: String, encoding: String.Encoding = .utf8) throws -> File {
        let file = try createFile(named: fileName)
        try file.write(string: contents, encoding: encoding)
        return file
    }

    /**
     *  Either return an existing file, or create a new one, for a given name
     *
     *  - parameter fileName: The name of the file to either get or create
     *  - parameter dataExpression: An expression resulting in any data that a new file should contain.
     *                              Will only be evaluated & used in case a new file is created.
     *
     *  - throws: `File.Error.writeFailed` if the file couldn't be created
     */
    @discardableResult public func createFileIfNeeded(withName fileName: String, contents dataExpression: @autoclosure () -> Data = .init()) throws -> File {
        if let existingFile = try? file(named: fileName) {
            return existingFile
        }

        return try createFile(named: fileName, contents: dataExpression())
    }
    
    /**
     *  Create a subfolder of this folder and return it
     *
     *  - parameter folderName: The name of the folder to create
     *
     *  - throws: `Folder.Error.creatingFolderFailed` if the subfolder couldn't be created
     *
     *  - returns: The folder that was created
     */
    @discardableResult public func createSubfolder(named folderName: String) throws -> Folder {
        let subfolderPath = path + folderName
        
        do {
            try fileManager.createDirectory(atPath: subfolderPath, withIntermediateDirectories: false, attributes: nil)
            return try Folder(path: subfolderPath, using: fileManager)
        } catch {
            throw Error.creatingFolderFailed
        }
    }

    /**
     *  Either return an existing subfolder, or create a new one, for a given name
     *
     *  - parameter folderName: The name of the folder to either get or create
     *
     *  - throws: `Folder.Error.creatingFolderFailed`
     */
    @discardableResult public func createSubfolderIfNeeded(withName folderName: String) throws -> Folder {
        if let existingFolder = try? subfolder(named: folderName) {
            return existingFolder
        }

        return try createSubfolder(named: folderName)
    }
    
    /**
     *  Create a sequence containing the files that are contained within this folder
     *
     *  - parameter recursive: Whether the files contained in all subfolders of this folder should also be included
     *  - parameter includeHidden: Whether hidden (dot) files should be included in the sequence (default: false)
     *
     *  If `recursive = true` the folder tree will be traversed depth-first
     */
    public func makeFileSequence(recursive: Bool = false, includeHidden: Bool = false) -> FileSystemSequence<File> {
        return FileSystemSequence(folder: self, recursive: recursive, includeHidden: includeHidden, using: fileManager)
    }
    
    /**
     *  Create a sequence containing the folders that are subfolders of this folder
     *
     *  - parameter recursive: Whether the entire folder tree contained under this folder should also be included
     *  - parameter includeHidden: Whether hidden (dot) files should be included in the sequence (default: false)
     *
     *  If `recursive = true` the folder tree will be traversed depth-first
     */
    public func makeSubfolderSequence(recursive: Bool = false, includeHidden: Bool = false) -> FileSystemSequence<Folder> {
        return FileSystemSequence(folder: self, recursive: recursive, includeHidden: includeHidden, using: fileManager)
    }

    /**
     *  Move the contents (both files and subfolders) of this folder to a new parent folder
     *
     *  - parameter newParent: The new parent folder that the contents of this folder should be moved to
     *  - parameter includeHidden: Whether hidden (dot) files should be moved (default: false)
     */
    public func moveContents(to newParent: Folder, includeHidden: Bool = false) throws {
        try makeFileSequence(includeHidden: includeHidden).forEach { try $0.move(to: newParent) }
        try makeSubfolderSequence(includeHidden: includeHidden).forEach { try $0.move(to: newParent) }
    }
    
    /**
     *  Empty this folder, removing all of its content
     *
     *  - parameter includeHidden: Whether hidden files (dot) files contained within the folder should also be removed
     *
     *  This will still keep the folder itself on disk. If you wish to delete the folder as well, call `delete()` on it.
     */
    public func empty(includeHidden: Bool = false) throws {
        try makeFileSequence(includeHidden: includeHidden).forEach { try $0.delete() }
        try makeSubfolderSequence(includeHidden: includeHidden).forEach { try $0.delete() }
    }
    
    /**
     *  Copy this folder to a new folder
     *
     *  - parameter folder: The folder that the folder should be copy to
     *
     *  - throws: `FileSystem.Item.OperationError.copyFailed` if the folder couldn't be copied
     */
    @discardableResult public func copy(to folder: Folder) throws -> Folder {
        let newPath = folder.path + name
        
        do {
            try fileManager.copyItem(atPath: path, toPath: newPath)
            return try Folder(path: newPath)
        } catch {
            throw OperationError.copyFailed(self)
        }
    }
}

/// Protocol adopted by file system types that may be iterated over (this protocol is an implementation detail)
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
public class FileSystemSequence<T: FileSystem.Item>: Sequence, CustomStringConvertible where T: FileSystemIterable {
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

    private let folder: Folder
    private let recursive: Bool
    private let includeHidden: Bool
    private let fileManager: FileManager

    fileprivate init(folder: Folder, recursive: Bool, includeHidden: Bool, using fileManager: FileManager) {
        self.folder = folder
        self.recursive = recursive
        self.includeHidden = includeHidden
        self.fileManager = fileManager
    }
    
    /// Create an iterator to use to iterate over the sequence
    public func makeIterator() -> FileSystemIterator<T> {
        return FileSystemIterator(folder: folder, recursive: recursive, includeHidden: includeHidden, using: fileManager)
    }
    
    /// Move all the items in this sequence to a new folder. See `FileSystem.Item.move(to:)` for more info.
    public func move(to newParent: Folder) throws {
        try forEach { try $0.move(to: newParent) }
    }

    public var description: String {
        return map { $0.description }.joined(separator: "\n")
    }
}

/// Iterator used to iterate over an instance of `FileSystemSequence`
public class FileSystemIterator<T: FileSystem.Item>: IteratorProtocol where T: FileSystemIterable {
    private let folder: Folder
    private let recursive: Bool
    private let includeHidden: Bool
    private let fileManager: FileManager
    private lazy var itemNames: [String] = {
        self.fileManager.itemNames(inFolderAtPath: self.folder.path)
    }()
    private lazy var childIteratorQueue = [FileSystemIterator]()
    private var currentChildIterator: FileSystemIterator?

    fileprivate init(folder: Folder, recursive: Bool, includeHidden: Bool, using fileManager: FileManager) {
        self.folder = folder
        self.recursive = recursive
        self.includeHidden = includeHidden
        self.fileManager = fileManager
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
        
        let nextItemPath = folder.path + nextItemName
        let nextItem = try? T(path: nextItemPath, using: fileManager)

        if recursive, let folder = (nextItem as? Folder) ?? (try? Folder(path: nextItemPath))  {
            let child = FileSystemIterator(folder: folder, recursive: true, includeHidden: includeHidden, using: fileManager)
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

    func loadModificationDate() -> Date {
        let attributes = try! fileManager.attributesOfItem(atPath: path)
        return attributes[FileAttributeKey.modificationDate] as! Date
    }
}

private extension FileManager {
    func itemKind(atPath path: String) -> FileSystem.Item.Kind? {
        var objCBool: ObjCBool = false
        
        guard fileExists(atPath: path, isDirectory: &objCBool) else {
            return nil
        }

        if objCBool.boolValue {
            return .folder
        }
        
        return .file
    }
    
    func itemNames(inFolderAtPath path: String) -> [String] {
        do {
            return try contentsOfDirectory(atPath: path).sorted()
        } catch {
            return []
        }
    }
    
    func absolutePath(for path: String) throws -> String {
        if path.hasPrefix("/") {
            return try pathByFillingInParentReferences(for: path)
        }
        
        if path.hasPrefix("~") {
            let prefixEndIndex = path.index(after: path.startIndex)
            
            let path = path.replacingCharacters(
                in: path.startIndex..<prefixEndIndex,
                with: ProcessInfo.processInfo.homeFolderPath
            )

            return try pathByFillingInParentReferences(for: path)
        }

        return try pathByFillingInParentReferences(for: path, prependCurrentFolderPath: true)
    }

    func parentPath(for path: String) -> String? {
        guard path != "/" else {
            return nil
        }

        var pathComponents = path.pathComponents

        if path.hasSuffix("/") {
            pathComponents.removeLast(2)
        } else {
            pathComponents.removeLast()
        }

        return pathComponents.joined(separator: "/")
    }

    func pathByFillingInParentReferences(for path: String, prependCurrentFolderPath: Bool = false) throws -> String {
        var path = path
        var filledIn = false

        while let parentReferenceRange = path.range(of: "../") {
            let currentFolderPath = String(path[..<parentReferenceRange.lowerBound])

            guard let currentFolder = try? Folder(path: currentFolderPath) else {
                throw FileSystem.Item.PathError.invalid(path)
            }

            guard let parent = currentFolder.parent else {
                throw FileSystem.Item.PathError.invalid(path)
            }

            path = path.replacingCharacters(in: path.startIndex..<parentReferenceRange.upperBound, with: parent.path)
            filledIn = true
        }

        if prependCurrentFolderPath {
            guard filledIn else {
                return currentDirectoryPath + "/" + path
            }
        }

        return path
    }
}

private extension String {
    var pathComponents: [String] {
        return components(separatedBy: "/")
    }
}

private extension ProcessInfo {
    var homeFolderPath: String {
        return environment["HOME"]!
    }
}

#if os(Linux) && !(swift(>=4.1))
private extension ObjCBool {
    var boolValue: Bool { return Bool(self) }
}
#endif

#if !os(Linux)
extension FileSystem {
    /// A reference to the document folder used by this file system.
    public var documentFolder: Folder? {
        guard let url = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return nil
        }
        
        return try? Folder(path: url.path, using: fileManager)
    }
    
    /// A reference to the library folder used by this file system.
    public var libraryFolder: Folder? {
        guard let url = try? fileManager.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return nil
        }
        
        return try? Folder(path: url.path, using: fileManager)
    }
}
#endif
