//
//  FileOpener.swift
//  Soundboard
//
//  Created by Tim Barber on 10/8/21.
//

import SwiftUI
import UniformTypeIdentifiers
import AVFoundation
import MobileCoreServices

struct InputDoument: FileDocument {

    static var readableContentTypes: [UTType] { [.plainText] }

    var input: String

    init(input: String) {
        self.input = input
    }

    init(configuration: FileDocumentReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        input = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: input.data(using: .utf8)!)
    }

}

struct MoviePicker: UIViewControllerRepresentable {

    @Environment(\.presentationMode)
    private var presentationMode

    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (URL) -> Void

    final class Coordinator: NSObject,
    UINavigationControllerDelegate,
    UIImagePickerControllerDelegate {

        @Binding
        private var presentationMode: PresentationMode
        private let sourceType: UIImagePickerController.SourceType
        private let onImagePicked: (URL) -> Void

        init(presentationMode: Binding<PresentationMode>,
             sourceType: UIImagePickerController.SourceType,
             onImagePicked: @escaping (URL) -> Void) {
            _presentationMode = presentationMode
            self.sourceType = sourceType
            self.onImagePicked = onImagePicked
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            onImagePicked(info[UIImagePickerController.InfoKey.mediaURL] as! URL)
            presentationMode.dismiss()

        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            presentationMode.dismiss()
        }

    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(presentationMode: presentationMode,
                           sourceType: sourceType,
                           onImagePicked: onImagePicked)
    }

    func makeUIViewController(context: UIViewControllerRepresentableContext<MoviePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        
        picker.mediaTypes = [UTType.movie.identifier]
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController,
                                context: UIViewControllerRepresentableContext<MoviePicker>) {

    }

}


class SoundFileManager {
    enum SoundFileManagerError: Error {
        case fileNotFound(fileName: String)
        case invalidExtension(extension: String)
        case nameToShort(nameLength: Int)
    }
    
    static var soundFolder = "Sounds"
    
    static func getFilePath(fileName: String, fileExtension: String, skipExistCheck: Bool = false) throws -> URL {
        let fileManager = FileManager.default
        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let soundFolderUrl = documentsUrl?.appendingPathComponent(self.soundFolder, isDirectory: true)
        if !ValidFileExtensions.isValidExtension(fileExtension: fileExtension){
            throw SoundFileManagerError.invalidExtension(extension: fileExtension)
        }
        var isDir : ObjCBool = false

        let fullUrl = soundFolderUrl?.appendingPathComponent(fileName).appendingPathExtension(fileExtension)
        guard skipExistCheck || fileManager.fileExists(atPath: fullUrl!.path, isDirectory:&isDir) else {
            throw SoundFileManagerError.fileNotFound(fileName: fullUrl!.path)
        }
        return fullUrl!
    }
    
    static func makeSoundFolder(deleteIfExists: Bool){
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let soundFolderURL = documentsURL!.appendingPathComponent(soundFolder, isDirectory: true)
        let fileManager = FileManager.default
        var isDir : ObjCBool = true
        if fileManager.fileExists(atPath: soundFolderURL.path, isDirectory:&isDir) {
            if isDir.boolValue && !deleteIfExists{
                // Nothing to do, directory exists
                return
            }
            else{
                // Exists as file or we asked to delete if dir exists, delete.
                print("File/Folder already exists, deleting")
                do {
                    try FileManager.default.removeItem(at: soundFolderURL)
                } catch let error as NSError {
                    print("Error: \(error.domain)")
                }
            }
        }
        
        // Make new folder
        print("Creating new folder")
        do
        {
            try FileManager.default.createDirectory(at: soundFolderURL, withIntermediateDirectories: true, attributes: nil)
        }
        catch let error as NSError
        {
            print("Unable to create directory \(error.debugDescription)")
        }
        print("Done creating new folder")
    }
    
    static func moveToLocal(filePath: URL) async throws{
        makeSoundFolder(deleteIfExists: false)
        let fileName = filePath.lastPathComponent
        let fileExtension = filePath.pathExtension
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let destURL = documentsURL!.appendingPathComponent(soundFolder, isDirectory: true).appendingPathComponent(fileName)
        if !ValidFileExtensions.isValidExtension(fileExtension: fileExtension){
            print("File extension not valid, attempting to convert")
            let conversionResult = try await FileConverter.extractAudioAndExport(sourceUrl: filePath, outputUrl: destURL.deletingPathExtension())
            if !conversionResult{
                print("Failed to convert file, file type is not valid")
                throw SoundFileManagerError.invalidExtension(extension: fileExtension)
            }
            return
        }

                let fileManager = FileManager.default
                try fileManager.copyItem(at: filePath, to: destURL)
    }
    
    static func renameFile(oldFileName: String, newFileName: String, fileExtension: String) throws{
        if (oldFileName == newFileName){
            print("File name did not change")
            return
        }
        let fileManager = FileManager.default
        try fileManager.moveItem(at: getFilePath(fileName: oldFileName, fileExtension: fileExtension), to: getFilePath(fileName: newFileName, fileExtension: fileExtension, skipExistCheck: true))
    }
    
    static func removeFile(fileName: String, fileExtension: String) throws{
        let fullURL = try getFilePath(fileName: fileName, fileExtension: fileExtension)
        let fileManager = FileManager.default
        try fileManager.removeItem(at: fullURL)
    }
    
    static func getAllSounds() -> [(fileName:String, fileExtension:String)]{
        self.makeSoundFolder(deleteIfExists: false)
        let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let soundFolderUrl = documentsUrl?.appendingPathComponent(soundFolder, isDirectory: true)
        var result: [(String,String)] = []
        do {
            // Get the directory contents urls (including subfolders urls)
            let directoryContents = try FileManager.default.contentsOfDirectory(at: soundFolderUrl!, includingPropertiesForKeys: nil)
            
            for contents in directoryContents{
                let newPath: [(String, String)] = [(contents.deletingPathExtension().lastPathComponent, contents.pathExtension)]
                result += newPath
            }
            return result

        } catch {
            print(error)
            return []
        }
    }
}


struct SoundRow: View {
    @FocusState private var keyboardFocused: Bool
    var onAdd : (String, String) -> ()
    var onRename : (String, String, String, String) -> ()
    var onRemove : (String, String) -> ()
    var promptRemove : (String, String) -> Bool
    var name: String
    var soundEngine: AVAudioEngine
    @State var fileName: String
    @State var fileExtension: String
    @ObservedObject var sound: AudioSample
    @State private var playing: Bool = false
    @State private var editing: Bool = false
    @State private var newFilename: String
    @State private var showDeleteAlert = false
    init(fileName: String, fileExtension: String, onAdd: @escaping (String, String) -> Void, onRename: @escaping (String, String, String, String) -> Void, onRemove: @escaping (String, String) -> Void, promptRemove: @escaping (String, String) -> Bool, soundEngine: AVAudioEngine) throws{
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.name = fileName + fileExtension
        self.sound = try AudioSample(fileName: fileName, fileExtension: fileExtension, soundEngine: soundEngine)
        self.onAdd = onAdd
        self.onRename = onRename
        self.onRemove = onRemove
        self.promptRemove = promptRemove
        self.newFilename = fileName
        self.soundEngine = soundEngine
        if (!self.soundEngine.isRunning){
            do{
               try self.soundEngine.start()
            }
            catch let error {
                print("Error starting sound engine: \(error.localizedDescription)")
            }
        }
    }
    var body: some View {
        HStack {
            // Main button for selectying tyhe file
            Button(action: {
                print("Selected " + self.name)
                onAdd(self.fileName, self.fileExtension)
            }){
                
            }.buttonStyle(DefaultButtonStyle()).frame(width: 1, height: 1)
            // TODO: Make text scrollabe if the filename is too long

            if(editing){
                TextField(
                        newFilename,
                        text: $newFilename
                    )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($keyboardFocused)
                .onSubmit {
                    editing = false
                }.frame(maxWidth: .infinity)
            }
            else{
                Text(self.fileName)
            }
                    
            // Button for playing sound. Must be borderless button to be compatible with the List view. Otherwise the entire list entry becomes the button
            Button(action:{
                if !sound.playing{
                    sound.play()
                }else{
                    sound.stop()
                }
            }){
            Image(systemName: sound.playing ? "stop.circle" : "play.circle").resizable().aspectRatio(contentMode: .fit)
            }.frame(alignment: .trailing)
            .buttonStyle(BorderlessButtonStyle()).frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: Alignment.trailing)
        }
        .onDisappear(){
            print("Destructing")
            self.sound.destroy()
        }
        .alert("There are currently sounds on the board that will be removed if you delete this sound, do you wish to continue?", isPresented: $showDeleteAlert){
            Button("Ok", role: .destructive){
                    do{
                        try SoundFileManager.removeFile(fileName: fileName, fileExtension: fileExtension)
                        onRemove(fileName, fileExtension)
                    }
                    catch{
                        
                    }
                }
        }
        .swipeActions(edge: .trailing) {
            Button() {
                do{
                    if promptRemove(fileName, fileExtension){
                        print("Prompting user for deletion confirmation")
                        showDeleteAlert = true
                    }
                    else{
                        print("No sounds present in grid, deleting sound")
                        try SoundFileManager.removeFile(fileName: fileName, fileExtension: fileExtension)
                        onRemove(fileName, fileExtension)
                    }

                }
                catch{
                    print("Error removing file")
                }
            }label: {
                Label("Delete", systemImage: "trash")
            }

            Button() {
                editing.toggle()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
        .onChange(of: keyboardFocused) { value in
            if !value{
                editing = false
            }
            
        }
        .onChange(of: editing){ value in
            if (value){
                keyboardFocused = true
            }
            else {
                keyboardFocused = false
                do{
                    try SoundFileManager.renameFile(oldFileName: fileName, newFileName: newFilename, fileExtension: fileExtension)
                    onRename(fileName, fileExtension, newFilename, fileExtension)
                    self.fileName = newFilename
                }
                catch{
                    print("Error renaming")
                }
            }
        }
    }
}

struct FileOpenView: View {
    @Environment(\.presentationMode) var presentationMode
    var onAdd : (String, String) -> ()
    var onRename : (String, String, String, String) -> ()
    var promptRemove : (String, String) -> Bool
    var onRemove : (String, String) -> ()
    var soundEngine: AVAudioEngine
    @State private var document: InputDoument = InputDoument(input: "")
    @State private var isImporting: Bool = false
    @State private var showImagePicker: Bool = false
    @State private var refresh: Bool = false
    
    func dismissOnAdd(fileName: String, fileExtension: String){
        onAdd(fileName, fileExtension)
        // Dismiss the view after calling the onAdd callback
        presentationMode.wrappedValue.dismiss()
    }
    
    var body: some View {
        NavigationView {
            List {
                let allSounds = SoundFileManager.getAllSounds()
                
                ForEach(0..<allSounds.count, id: \.self) { index in
                    try? SoundRow(fileName: allSounds[index].fileName, fileExtension: allSounds[index].fileExtension, onAdd: dismissOnAdd, onRename: onRename, onRemove: onRemove, promptRemove: promptRemove, soundEngine: soundEngine).frame(height: 30)
                }
            }
            .id(isImporting)
            .id(showImagePicker)
            .id(refresh)
                  .navigationBarTitleDisplayMode(.inline)
                  .navigationBarTitle("Sound Library").font(.title2)
                  .navigationBarItems(trailing:
                                        HStack{
                      Button(action: {
                        isImporting = true
                      }) {
                          Text("File").font(.title3)
                      }
                        Button(action: {
                        showImagePicker = true
                            }) {
                                Text("Library").font(.title3)
                            }
                  }
                  )

                                      }
        .padding()
        .fileImporter(
                    isPresented: $isImporting,
                    allowedContentTypes: [.audio, .video, .movie],
                    allowsMultipleSelection: true
                ) { result in
                    isImporting = false
                    do {
                        let selectedFiles: [URL] = try result.get()
                        Task{
                            for url in selectedFiles{
                                if url.startAccessingSecurityScopedResource() {
                                    do {
                                        try await SoundFileManager.moveToLocal(filePath: url)
                                        print(url.absoluteString + " copied to local")
                                        url.stopAccessingSecurityScopedResource()
                                        refresh.toggle()
                                        document.input = "file loaded"
                                    } catch {
                                        // Handle failure.
                                        print(error.localizedDescription)
                                    }
                                }
                                else{
                                    url.stopAccessingSecurityScopedResource()
                                }
                            }

                        }
                    } catch {
                        // Handle failure.
                        print(error.localizedDescription)
                    }
                }
        .sheet(isPresented: $showImagePicker) {
            MoviePicker(sourceType: .photoLibrary) { selectedFile in
                        showImagePicker = false
                        Task{
                            do {
                                try await SoundFileManager.moveToLocal(filePath: selectedFile)
                                print(selectedFile.absoluteString + " copied to local")
                                refresh.toggle()
                            } catch {
                                // Handle failure.
                                print(error.localizedDescription)
                            }
                        }
                        
                    }
        }
}
}

class FileConverter {
    static func extractAudioAndExport(sourceUrl: URL, outputUrl: URL) async throws -> Bool{
           // Create a composition
           let composition = AVMutableComposition()
           do {
               let asset = AVURLAsset(url: sourceUrl)
               let audioAssetTrack = try await asset.loadTracks(withMediaType: AVMediaType.audio).first
               let audioCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid)
               let timeRange = try await audioAssetTrack!.load(.timeRange)
               try audioCompositionTrack!.insertTimeRange(timeRange, of: audioAssetTrack!, at: CMTime.zero)
           } catch {
               print(error)
               return false
           }

           // Get url for output
           if FileManager.default.fileExists(atPath: outputUrl.path) {
               try? FileManager.default.removeItem(atPath: outputUrl.path)
           }

           // Create an export session
           let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)!
           exportSession.outputFileType = AVFileType.m4a
           exportSession.outputURL = outputUrl.appendingPathExtension("m4a")

        // Export file
        await exportSession.export()
        print("Conversion complete")
        return true
       }

}

struct FileOpenView_Previews: PreviewProvider {
    static func onAdd(fileName: String, fileExtension: String){
        return
    }
    static func onRename(newFileName: String, newFileExtension: String, oldFileName: String, oldFileExtension: String){
        return
    }
    static func onRemove(fileName: String, fileExtension: String){
        return
    }
    static func promptRemove(fileName: String, fileExtension: String) -> Bool{
        return false
    }
    static var previews: some View {
        FileOpenView(onAdd: onAdd, onRename: onRename, promptRemove: promptRemove, onRemove: onRemove, soundEngine: AVAudioEngine())
    }
}
