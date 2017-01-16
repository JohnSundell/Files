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
    let folder = FileSystem().temporaryFolder
    
    // MARK: - Tests
    
    func testCreatingAndDeletingFile() {
        performTest {
            // Create a file and verify its properties
            let file = try folder.createFile(named: "test")
            XCTAssertEqual(file.name, "test")
            XCTAssertEqual(file.path, folder.path + "test")
            try XCTAssertEqual(file.read(), Data())
            
            // You should now be able to access the file using its path
            _ = try File(path: file.path)

            try file.delete()
            
            // Attempting to read the file should now throw an error
            try assert(file.read(), throwsError: File.Error.readFailed)
            
            // Attempting to create a File instance with the path should now also fail
            try assert(File(path: file.path), throwsError: File.PathError.invalid(file.path))
        }
    }
    
    func testCreatingAndDeletingFolder() {
        performTest {
            // Create a folder and verify its properties
            let subfolder = try folder.createSubfolder(named: "folder")
            XCTAssertEqual(subfolder.name, "folder")
            XCTAssertEqual(subfolder.path, folder.path + "folder/")
            
            // You should now be able to access the folder using its path
            _ = try Folder(path: subfolder.path)
            
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
    
    func testRenamingFile() {
        performTest {
            let file = try folder.createFile(named: "file")
            try file.rename(to: "renamedFile")
            XCTAssertEqual(file.name, "renamedFile")
            XCTAssertEqual(file.path, folder.path + "renamedFile")
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
    
    func testEnumeratingFiles() {
        performTest {
            try folder.createFile(named: "1")
            try folder.createFile(named: "2")
            try folder.createFile(named: "3")
            
            XCTAssertEqual(folder.files.names, ["1", "2", "3"])
            XCTAssertEqual(folder.files.count, 3)
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
            
            XCTAssertEqual(folder.subfolders.names, ["1", "2", "3"])
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
            
            let expectedNames = ["1", "2", "1A", "1B", "2A", "2B"]
            let sequence = folder.makeSubfolderSequence(recursive: true)
            XCTAssertEqual(sequence.names, expectedNames)
            XCTAssertEqual(sequence.count, 6)
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
    
    func testAccessingHomeFolder() {
        XCTAssertNotNil(FileSystem().homeFolder)
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
            let subfolder = try fileSystem.temporaryFolder.createSubfolder(named: "folder")
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
}
