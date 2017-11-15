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
import XCTest
import Files

class FilesTests: XCTestCase {
    private var folder: Folder!

    // MARK: - XCTestCase

    override func setUp() {
        super.setUp()
        folder = try! Folder.home.createSubfolderIfNeeded(withName: ".filesTest")
        try! folder.empty()
    }

    override func tearDown() {
        try? folder.delete()
        super.tearDown()
    }
    
    // MARK: - Tests
    
    func testCreatingAndDeletingFile() {
        performTest {
            // Verify that the file doesn't exist
            XCTAssertFalse(folder.containsFile(named: "test.txt"))

            // Create a file and verify its properties
            let file = try folder.createFile(named: "test.txt")
            XCTAssertEqual(file.name, "test.txt")
            XCTAssertEqual(file.path, folder.path + "test.txt")
            XCTAssertEqual(file.extension, "txt")
            XCTAssertEqual(file.nameExcludingExtension, "test")
            try XCTAssertEqual(file.read(), Data())
            
            // You should now be able to access the file using its path and through the parent
            _ = try File(path: file.path)
            XCTAssertTrue(folder.containsFile(named: "test.txt"))

            try file.delete()
            
            // Attempting to read the file should now throw an error
            try assert(file.read(), throwsError: File.Error.readFailed)
            
            // Attempting to create a File instance with the path should now also fail
            try assert(File(path: file.path), throwsError: File.PathError.invalid(file.path))
        }
    }
    
    func testCreatingAndDeletingFolder() {
        performTest {
            // Verify that the folder doesn't exist
            XCTAssertFalse(folder.containsSubfolder(named: "folder"))

            // Create a folder and verify its properties
            let subfolder = try folder.createSubfolder(named: "folder")
            XCTAssertEqual(subfolder.name, "folder")
            XCTAssertEqual(subfolder.path, folder.path + "folder/")
            
            // You should now be able to access the folder using its path and through the parent
            _ = try Folder(path: subfolder.path)
            XCTAssertTrue(folder.containsSubfolder(named: "folder"))
            
            // Put a file in the folder
            let file = try subfolder.createFile(named: "file")
            try XCTAssertEqual(file.read(), Data())
            
            try subfolder.delete()
            
            // Attempting to create a Folder instance with the path should now fail
            try assert(Folder(path: subfolder.path), throwsError: Folder.PathError.invalid(subfolder.path))
            
            // The file contained in the folder should now also be deleted
            try assert(file.read(), throwsError: File.Error.readFailed)
        }
    }

    func testReadingFileAsString() {
        performTest {
            let file = try folder.createFile(named: "string", contents: "Hello".data(using: .utf8)!)
            try XCTAssertEqual(file.readAsString(), "Hello")
        }
    }

    func testReadingFileAsInt() {
        performTest {
            let intFile = try folder.createFile(named: "int", contents: "\(7)".data(using: .utf8)!)
            try XCTAssertEqual(intFile.readAsInt(), 7)

            let nonIntFile = try folder.createFile(named: "nonInt", contents: "Not an int".data(using: .utf8)!)
            try assert(nonIntFile.readAsInt(), throwsError: File.Error.readFailed)
        }
    }
    
    func testRenamingFile() {
        performTest {
            let file = try folder.createFile(named: "file.json")
            try file.rename(to: "renamedFile")
            XCTAssertEqual(file.name, "renamedFile.json")
            XCTAssertEqual(file.path, folder.path + "renamedFile.json")
            XCTAssertEqual(file.extension, "json")
            
            // Now try renaming the file, replacing its extension
            try file.rename(to: "other.txt", keepExtension: false)
            XCTAssertEqual(file.name, "other.txt")
            XCTAssertEqual(file.path, folder.path + "other.txt")
            XCTAssertEqual(file.extension, "txt")
        }
    }
    
    func testRenamingFileWithNameIncludingExtension() {
        performTest {
            let file = try folder.createFile(named: "file.json")
            try file.rename(to: "renamedFile.json")
            XCTAssertEqual(file.name, "renamedFile.json")
            XCTAssertEqual(file.path, folder.path + "renamedFile.json")
            XCTAssertEqual(file.extension, "json")
        }
    }
    
    func testReadingFileWithRelativePath() {
        performTest {
            try folder.createFile(named: "file")
            
            // Make sure we're not already in the file's parent directory
            XCTAssertNotEqual(FileManager.default.currentDirectoryPath, folder.path)
            
            XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(folder.path))
            let file = try File(path: "file")
            try XCTAssertEqual(file.read(), Data())
        }
    }
    
    func testReadingFileWithTildePath() {
        performTest {
            try folder.createFile(named: "File")
            let file = try File(path: "~/.filesTest/File")
            try XCTAssertEqual(file.read(), Data())
            XCTAssertEqual(file.path, folder.path + "File")

            // Cleanup since we're performing a test in the actual home folder
            try file.delete()
        }
    }

    func testReadingFileFromCurrentFoldersParent() {
        performTest {
            let subfolder = try folder.createSubfolder(named: "folder")
            let file = try folder.createFile(named: "file")

            // Move to the subfolder
            XCTAssertNotEqual(FileManager.default.currentDirectoryPath, subfolder.path)
            XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(subfolder.path))

            try XCTAssertEqual(File(path: "../file"), file)
        }
    }

    func testReadingFileWithMultipleParentReferencesWithinPath() {
        performTest {
            let subfolderA = try folder.createSubfolder(named: "A")
            try folder.createSubfolder(named: "B")
            let subfolderC = try folder.createSubfolder(named: "C")
            let file = try subfolderC.createFile(named: "file")

            try XCTAssertEqual(File(path: subfolderA.path + "../B/../C/file"), file)
        }
    }
    
    func testRenamingFolder() {
        performTest {
            let subfolder = try folder.createSubfolder(named: "folder")
            try subfolder.rename(to: "renamedFolder")
            XCTAssertEqual(subfolder.name, "renamedFolder")
            XCTAssertEqual(subfolder.path, folder.path + "renamedFolder/")
        }
    }

    func testAccesingFileByPath() {
        performTest {
            let subfolderA = try folder.createSubfolder(named: "A")
            let subfolderB = try subfolderA.createSubfolder(named: "B")
            let file = try subfolderB.createFile(named: "C")
            try XCTAssertEqual(folder.file(atPath: "A/B/C"), file)
        }
    }

    func testAccessingSubfolderByPath() {
        performTest {
            let subfolderA = try folder.createSubfolder(named: "A")
            let subfolderB = try subfolderA.createSubfolder(named: "B")
            let subfolderC = try subfolderB.createSubfolder(named: "C")
            try XCTAssertEqual(folder.subfolder(atPath: "A/B/C"), subfolderC)
        }
    }

    func testEmptyingFolder() {
        performTest {
            try folder.createFile(named: "A")
            try folder.createFile(named: "B")
            XCTAssertEqual(folder.files.count, 2)

            try folder.empty()
            XCTAssertEqual(folder.files.count, 0)
        }
    }

    func testEmptyingFolderWithHiddenFiles() {
        performTest {
            let subfolder = try folder.createSubfolder(named: "folder")

            try subfolder.createFile(named: "A")
            try subfolder.createFile(named: ".B")
            XCTAssertEqual(subfolder.makeFileSequence(includeHidden: true).count, 2)

            // Per default, hidden files should not be deleted
            try subfolder.empty()
            XCTAssertEqual(subfolder.makeFileSequence(includeHidden: true).count, 1)

            try subfolder.empty(includeHidden: true)
            XCTAssertEqual(folder.files.count, 0)
        }
    }
    
    func testMovingFiles() {
        performTest {
            try folder.createFile(named: "A")
            try folder.createFile(named: "B")
            XCTAssertEqual(folder.files.count, 2)
            
            let subfolder = try folder.createSubfolder(named: "folder")
            try folder.files.move(to: subfolder)
            try XCTAssertNotNil(subfolder.file(named: "A"))
            try XCTAssertNotNil(subfolder.file(named: "B"))
            XCTAssertEqual(folder.files.count, 0)
        }
    }
    
    func testCopyingFiles() {
        performTest {
            let file = try folder.createFile(named: "A")
            try file.write(string: "content")
            
            let subfolder = try folder.createSubfolder(named: "folder")
            try file.copy(to: subfolder)
            try XCTAssertNotNil(folder.file(named: "A"))
            try XCTAssertNotNil(subfolder.file(named: "A"))
            try XCTAssertEqual(file.read(), subfolder.file(named: "A").read())
            XCTAssertEqual(folder.files.count, 1)
        }
    }
    
    func testCopyingFolders() {
        performTest {
            let copyingFolder = try folder.createSubfolder(named: "A")
            
            let subfolder = try folder.createSubfolder(named: "folder")
            try copyingFolder.copy(to: subfolder)
            XCTAssertTrue(folder.containsSubfolder(named: "A"))
            XCTAssertTrue(subfolder.containsSubfolder(named: "A"))
            XCTAssertEqual(folder.subfolders.count, 2)
            XCTAssertEqual(subfolder.subfolders.count, 1)
        }
    }
    
    func testEnumeratingFiles() {
        performTest {
            try folder.createFile(named: "1")
            try folder.createFile(named: "2")
            try folder.createFile(named: "3")
            
            // Hidden files should be excluded by default
            try folder.createFile(named: ".hidden")
            
            XCTAssertEqual(folder.files.names.sorted(), ["1", "2", "3"])
            XCTAssertEqual(folder.files.count, 3)
        }
    }
    
    func testEnumeratingFilesIncludingHidden() {
        performTest {
            let subfolder = try folder.createSubfolder(named: "folder")
            try subfolder.createFile(named: ".hidden")
            try subfolder.createFile(named: "visible")
            
            let files = subfolder.makeFileSequence(includeHidden: true)
            XCTAssertEqual(files.names.sorted(), [".hidden", "visible"])
            XCTAssertEqual(files.count, 2)
        }
    }
    
    func testEnumeratingFilesRecursively() {
        performTest {
            let subfolder1 = try folder.createSubfolder(named: "1")
            let subfolder2 = try folder.createSubfolder(named: "2")
            
            let subfolder1A = try subfolder1.createSubfolder(named: "A")
            let subfolder1B = try subfolder1.createSubfolder(named: "B")
            
            let subfolder2A = try subfolder2.createSubfolder(named: "A")
            let subfolder2B = try subfolder2.createSubfolder(named: "B")
            
            try subfolder1.createFile(named: "File1")
            try subfolder1A.createFile(named: "File1A")
            try subfolder1B.createFile(named: "File1B")
            try subfolder2.createFile(named: "File2")
            try subfolder2A.createFile(named: "File2A")
            try subfolder2B.createFile(named: "File2B")
            
            let expectedNames = ["File1", "File1A", "File1B", "File2", "File2A", "File2B"]
            let sequence = folder.makeFileSequence(recursive: true)
            XCTAssertEqual(sequence.names, expectedNames)
            XCTAssertEqual(sequence.count, 6)
        }
    }
    
    func testEnumeratingSubfolders() {
        performTest {
            try folder.createSubfolder(named: "1")
            try folder.createSubfolder(named: "2")
            try folder.createSubfolder(named: "3")
            
            XCTAssertEqual(folder.subfolders.names.sorted(), ["1", "2", "3"])
            XCTAssertEqual(folder.subfolders.count, 3)
        }
    }
    
    func testEnumeratingSubfoldersRecursively() {
        performTest {
            let subfolder1 = try folder.createSubfolder(named: "1")
            let subfolder2 = try folder.createSubfolder(named: "2")
            
            try subfolder1.createSubfolder(named: "1A")
            try subfolder1.createSubfolder(named: "1B")
            
            try subfolder2.createSubfolder(named: "2A")
            try subfolder2.createSubfolder(named: "2B")
            
            let expectedNames = ["1", "1A", "1B", "2", "2A", "2B"]
            let sequence = folder.makeSubfolderSequence(recursive: true)
            XCTAssertEqual(sequence.names.sorted(), expectedNames)
            XCTAssertEqual(sequence.count, 6)
        }
    }

    func testRenamingFoldersWhileEnumeratingSubfoldersRecursively() {
        performTest {
            let subfolder1 = try folder.createSubfolder(named: "1")
            let subfolder2 = try folder.createSubfolder(named: "2")

            try subfolder1.createSubfolder(named: "1A")
            try subfolder1.createSubfolder(named: "1B")

            try subfolder2.createSubfolder(named: "2A")
            try subfolder2.createSubfolder(named: "2B")

            let sequence = folder.makeSubfolderSequence(recursive: true)

            for folder in sequence {
                try folder.rename(to: "Folder " + folder.name)
            }

            let expectedNames = ["Folder 1", "Folder 1A", "Folder 1B", "Folder 2", "Folder 2A", "Folder 2B"]

            XCTAssertEqual(sequence.names.sorted(), expectedNames)
            XCTAssertEqual(sequence.count, 6)
        }
    }
    
    func testFirstAndLastInFileSequence() {
        performTest {
            try folder.createFile(named: "A")
            try folder.createFile(named: "B")
            try folder.createFile(named: "C")
            
            XCTAssertEqual(folder.files.first?.name, "A")
            XCTAssertEqual(folder.files.last?.name, "C")
        }
    }

    func testModificationDate() {
        performTest {
            let subfolder = try folder.createSubfolder(named: "Folder")
            XCTAssertTrue(Calendar.current.isDateInToday(subfolder.modificationDate))

            let file = try folder.createFile(named: "File")
            XCTAssertTrue(Calendar.current.isDateInToday(file.modificationDate))
        }
    }
    
    func testParent() {
        performTest {
            try XCTAssertEqual(folder.createFile(named: "test").parent, folder)
            
            let subfolder = try folder.createSubfolder(named: "subfolder")
            XCTAssertEqual(subfolder.parent, folder)
            try XCTAssertEqual(subfolder.createFile(named: "test").parent, subfolder)
        }
    }
    
    func testRootFolderParentIsNil() {
        performTest {
            try XCTAssertNil(Folder(path: "/").parent)
        }
    }
    
    func testOpeningFileWithEmptyPathThrows() {
        performTest {
            try assert(File(path: ""), throwsError: File.PathError.empty)
        }
    }
    
    func testDeletingNonExistingFileThrows() {
        performTest {
            let file = try folder.createFile(named: "file")
            try file.delete()
            try assert(file.delete(), throwsError: File.OperationError.deleteFailed(file))
        }
    }
    
    func testWritingDataToFile() {
        performTest {
            let file = try folder.createFile(named: "file")
            try XCTAssertEqual(file.read(), Data())
            
            let data = "New content".data(using: .utf8)!
            try file.write(data: data)
            try XCTAssertEqual(file.read(), data)
        }
    }
    
    func testWritingStringToFile() {
        performTest {
            let file = try folder.createFile(named: "file")
            try XCTAssertEqual(file.read(), Data())
            
            try file.write(string: "New content")
            try XCTAssertEqual(file.read(), "New content".data(using: .utf8))
        }
    }
    
    func testFileDescription() {
        performTest {
            let file = try folder.createFile(named: "file")
            XCTAssertEqual(file.description, "File(name: file, path: \(folder.path)file)")
        }
    }
    
    func testFolderDescription() {
        performTest {
            let subfolder = try folder.createSubfolder(named: "folder")
            XCTAssertEqual(subfolder.description, "Folder(name: folder, path: \(folder.path)folder/)")
        }
    }

    func testMovingFolderContents() {
        performTest {
            let parentFolder = try folder.createSubfolder(named: "parentA")
            try parentFolder.createSubfolder(named: "folderA")
            try parentFolder.createSubfolder(named: "folderB")
            try parentFolder.createFile(named: "fileA")
            try parentFolder.createFile(named: "fileB")

            XCTAssertEqual(parentFolder.subfolders.names, ["folderA", "folderB"])
            XCTAssertEqual(parentFolder.files.names, ["fileA", "fileB"])

            let newParentFolder = try folder.createSubfolder(named: "parentB")
            try parentFolder.moveContents(to: newParentFolder)

            XCTAssertEqual(parentFolder.subfolders.names, [])
            XCTAssertEqual(parentFolder.files.names, [])
            XCTAssertEqual(newParentFolder.subfolders.names, ["folderA", "folderB"])
            XCTAssertEqual(newParentFolder.files.names, ["fileA", "fileB"])
        }
    }
    
    func testMovingFolderHiddenContents() {
        performTest {
            let parentFolder = try folder.createSubfolder(named: "parent")
            try parentFolder.createFile(named: ".hidden")
            try parentFolder.createSubfolder(named: ".folder")
            
            XCTAssertEqual(parentFolder.makeFileSequence(includeHidden: true).names, [".hidden"])
            XCTAssertEqual(parentFolder.makeSubfolderSequence(includeHidden: true).names, [".folder"])
            
            let newParentFolder = try folder.createSubfolder(named: "parentB")
            try parentFolder.moveContents(to: newParentFolder, includeHidden: true)
            
            XCTAssertEqual(parentFolder.makeFileSequence(includeHidden: true).names, [])
            XCTAssertEqual(parentFolder.makeSubfolderSequence(includeHidden: true).names, [])
            XCTAssertEqual(newParentFolder.makeFileSequence(includeHidden: true).names, [".hidden"])
            XCTAssertEqual(newParentFolder.makeSubfolderSequence(includeHidden: true).names, [".folder"])
        }
    }

    func testAccessingHomeFolder() {
        XCTAssertNotNil(FileSystem().homeFolder)
        XCTAssertNotNil(Folder.home)
    }

    func testAccessingCurrentWorkingDirectory() {
        performTest {
            let folder = try Folder(path: "")
            XCTAssertEqual(FileManager.default.currentDirectoryPath + "/", folder.path)
            XCTAssertEqual(FileSystem().currentFolder, folder)
            XCTAssertEqual(Folder.current, folder)
        }
    }
    
    func testNameExcludingExtensionWithLongFileName() {
        performTest {
            let file = try folder.createFile(named: "AVeryLongFileName.png")
            XCTAssertEqual(file.nameExcludingExtension, "AVeryLongFileName")
        }
    }

    func testCreatingFileFromFileSystem() {
        performTest {
            let fileName = "three"
            let filePath = folder.path + "one/two/\(fileName)"
            let contents = Data()
            let file = try FileSystem().createFile(at: filePath, contents: contents)

            XCTAssertEqual(file.name, fileName)
            XCTAssertEqual(file.path, filePath)

            try XCTAssertEqual(File(path: filePath).read(), contents)
        }
    }

    func testCreateFileFromFileSystemIfNeeded() {
        performTest {
            let path = folder.path + "one/two/three/file"
            let contentA = "Hello".data(using: .utf8)!
            let contentB = "World".data(using: .utf8)!
            let fileA = try FileSystem().createFileIfNeeded(at: path, contents: contentA)
            let fileB = try FileSystem().createFileIfNeeded(at: path, contents: contentB)

            try XCTAssertEqual(fileA.readAsString(), "Hello")
            try XCTAssertEqual(fileA.read(), fileB.read())
        }
    }

    func testCreatingFolderFromFileSystem() {
        performTest {
            let folderPath = folder.path + "one/two/three"
            try FileSystem().createFolder(at: folderPath)
            _ = try Folder(path: folderPath)
        }
    }

    func testCreatingFolderWithTildePathFromFileSystem() {
        performTest {
            let fileSystem = FileSystem()
            try fileSystem.createFolder(at: "~/.filesTestFolder")
            let createdFolder = try fileSystem.homeFolder.subfolder(named: ".filesTestFolder")

            // Cleanup since we're performing a test in the actual home folder
            try createdFolder.delete()
        }
    }

    func testCreateFileIfNeeded() {
        performTest {
            let fileA = try folder.createFileIfNeeded(withName: "file", contents: "Hello".data(using: .utf8)!)
            let fileB = try folder.createFileIfNeeded(withName: "file", contents: "World".data(using: .utf8)!)
            try XCTAssertEqual(fileA.readAsString(), "Hello")
            try XCTAssertEqual(fileA.read(), fileB.read())
        }
    }

    func testCreateFolderIfNeeded() {
        performTest {
            let subfolderA = try FileSystem().createFolderIfNeeded(at: folder.path + "one/two/three")
            try subfolderA.createFile(named: "file")
            let subfolderB = try FileSystem().createFolderIfNeeded(at: subfolderA.path)
            XCTAssertEqual(subfolderA, subfolderB)
            XCTAssertEqual(subfolderA.files.count, subfolderB.files.count)
            XCTAssertEqual(subfolderA.files.first, subfolderB.files.first)
        }
    }

    func testCreateSubfolderIfNeeded() {
        performTest {
            let subfolderA = try folder.createSubfolderIfNeeded(withName: "folder")
            try subfolderA.createFile(named: "file")
            let subfolderB = try folder.createSubfolderIfNeeded(withName: "folder")
            XCTAssertEqual(subfolderA, subfolderB)
            XCTAssertEqual(subfolderA.files.count, subfolderB.files.count)
            XCTAssertEqual(subfolderA.files.first, subfolderB.files.first)
        }
    }
    
    func testCreatingFileWithString() {
        performTest {
            let file = try folder.createFile(named: "file", contents: "Hello world")
            XCTAssertEqual(try file.readAsString(), "Hello world")
        }
    }
    
    func testUsingCustomFileManager() {
        class FileManagerMock: FileManager {
            var noFilesExist = false
            
            override func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
                if noFilesExist {
                    return false
                }
                
                return super.fileExists(atPath: path, isDirectory: isDirectory)
            }
        }
        
        performTest {
            let fileManager = FileManagerMock()
            let fileSystem = FileSystem(using: fileManager)
            let subfolder = try fileSystem.temporaryFolder.createSubfolder(named: UUID().uuidString)
            let file = try subfolder.createFile(named: "file")
            try XCTAssertEqual(file.read(), Data())
        
            // Mock that no files exist, which should call file lookups to fail
            fileManager.noFilesExist = true
            try assert(subfolder.file(named: "file"), throwsError: File.PathError.invalid(file.path))
        }
    }
    
    // MARK: - Utilities
    
    private func performTest(closure: () throws -> Void) {
        do {
            try folder.empty()
            try closure()
        } catch {
            XCTFail("Unexpected error thrown: \(error)")
        }
    }
    
    private func assert<T, E: Error>(_ expression: @autoclosure () throws -> T, throwsError expectedError: E) where E: Equatable {
        do {
            _ = try expression()
            XCTFail("Expected error to be thrown")
        } catch let error as E {
            XCTAssertEqual(error, expectedError)
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }
    
    // MARK: - Linux
    
    static var allTests = [
        ("testCreatingAndDeletingFile", testCreatingAndDeletingFile),
        ("testCreatingAndDeletingFolder", testCreatingAndDeletingFolder),
        ("testReadingFileAsString", testReadingFileAsString),
        ("testReadingFileAsInt", testReadingFileAsInt),
        ("testRenamingFile", testRenamingFile),
        ("testRenamingFileWithNameIncludingExtension", testRenamingFileWithNameIncludingExtension),
        ("testReadingFileWithRelativePath", testReadingFileWithRelativePath),
        ("testReadingFileWithTildePath", testReadingFileWithTildePath),
        ("testReadingFileFromCurrentFoldersParent", testReadingFileFromCurrentFoldersParent),
        ("testReadingFileWithMultipleParentReferencesWithinPath", testReadingFileWithMultipleParentReferencesWithinPath),
        ("testRenamingFolder", testRenamingFolder),
        ("testAccesingFileByPath", testAccesingFileByPath),
        ("testAccessingSubfolderByPath", testAccessingSubfolderByPath),
        ("testEmptyingFolder", testEmptyingFolder),
        ("testEmptyingFolderWithHiddenFiles", testEmptyingFolderWithHiddenFiles),
        ("testMovingFiles", testMovingFiles),
        ("testCopyingFiles", testCopyingFiles),
        ("testCopyingFolders", testCopyingFolders),
        ("testEnumeratingFiles", testEnumeratingFiles),
        ("testEnumeratingFilesIncludingHidden", testEnumeratingFilesIncludingHidden),
        ("testEnumeratingFilesRecursively", testEnumeratingFilesRecursively),
        ("testEnumeratingSubfolders", testEnumeratingSubfolders),
        ("testEnumeratingSubfoldersRecursively", testEnumeratingSubfoldersRecursively),
        ("testRenamingFoldersWhileEnumeratingSubfoldersRecursively", testRenamingFoldersWhileEnumeratingSubfoldersRecursively),
        ("testFirstAndLastInFileSequence", testFirstAndLastInFileSequence),
        ("testModificationDate", testModificationDate),
        ("testParent", testParent),
        ("testRootFolderParentIsNil", testRootFolderParentIsNil),
        ("testOpeningFileWithEmptyPathThrows", testOpeningFileWithEmptyPathThrows),
        ("testDeletingNonExistingFileThrows", testDeletingNonExistingFileThrows),
        ("testWritingDataToFile", testWritingDataToFile),
        ("testWritingStringToFile", testWritingStringToFile),
        ("testFileDescription", testFileDescription),
        ("testFolderDescription", testFolderDescription),
        ("testMovingFolderContents", testMovingFolderContents),
        ("testMovingFolderHiddenContents", testMovingFolderHiddenContents),
        ("testAccessingHomeFolder", testAccessingHomeFolder),
        ("testAccessingCurrentWorkingDirectory", testAccessingCurrentWorkingDirectory),
        ("testNameExcludingExtensionWithLongFileName", testNameExcludingExtensionWithLongFileName),
        ("testCreatingFileFromFileSystem", testCreatingFileFromFileSystem),
        ("testCreateFileFromFileSystemIfNeeded", testCreateFileFromFileSystemIfNeeded),
        ("testCreatingFolderFromFileSystem", testCreatingFolderFromFileSystem),
        ("testCreatingFolderWithTildePathFromFileSystem", testCreatingFolderWithTildePathFromFileSystem),
        ("testCreateFileIfNeeded", testCreateFileIfNeeded),
        ("testCreateFolderIfNeeded", testCreateFolderIfNeeded),
        ("testCreateSubfolderIfNeeded", testCreateSubfolderIfNeeded),
        ("testCreatingFileWithString", testCreatingFileWithString),
        ("testUsingCustomFileManager", testUsingCustomFileManager)
    ]
}

#if !os(Linux)
extension FilesTests {
    func testAccessingDocumentFolder() {
        #if os(tvOS)
            XCTAssertNil(FileSystem().documentFolder, "Document folder should not be available on tvOS.")
        #else
            XCTAssertNotNil(FileSystem().documentFolder, "Document folder should be available.")
        #endif
    }
    
    func testAccessingLibraryFolder() {
        XCTAssertNotNil(FileSystem().libraryFolder, "Library folder should be available.")
    }
}
#endif
