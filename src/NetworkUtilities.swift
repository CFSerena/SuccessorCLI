import Foundation

let group = DispatchGroup()
let sema = DispatchSemaphore(value: 0)
/// Utilities for making HTTP requests & downloading items
class NetworkUtilities:NSObject {
    static let shared = NetworkUtilities()
    
    /// Returns info from ipsw.me's v4 API, which can be returned in other JSON or XML, docs: https://ipswdownloads.docs.apiary.io/
    func retJSONFromURL(url:String, completion: @escaping (String) -> Void) {
        group.enter()
        let task = URLSession.shared.dataTask(with: URL(string: url)!) { (data, response, error ) in
            guard let data = data, error == nil,
                  let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                      print("Error while getting online iPSW Info: \(error?.localizedDescription ?? "Unknown error")")
                      exit(EXIT_FAILURE)
                  }
            guard let strResponse = String(data: data, encoding: .utf8) else {
                print("Error encountered while converting JSON Response from ipsw.me to string..exiting..")
                exit(EXIT_FAILURE)
            }
            completion(strResponse)
            group.leave()
        }
        task.resume()
        group.wait()
    }
    var downloadItemDestination = ""
    func downloadItem(url: URL, destinationURL: URL) {
        downloadItemDestination = destinationURL.path
        let task = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        task.downloadTask(with: url).resume()
        sema.wait()
        }
}


extension NetworkUtilities: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo: URL) {
        print("finished downloading item to \(didFinishDownloadingTo)")
        if fm.fileExists(atPath: self.downloadItemDestination) {
            print("\(self.downloadItemDestination) Already exists.. will try to remove it and put the newly downloaded file..")
            do {
                try fm.removeItem(atPath: self.downloadItemDestination)
                print("Removed \(self.downloadItemDestination), now placing \(didFinishDownloadingTo) there..")
            } catch {
                errPrint("Error encountered while removing \(self.downloadItemDestination): \(error). Exiting..", line: #line, file: #file)
                exit(EXIT_FAILURE)
            }
        }
        do {
            try fm.moveItem(at: didFinishDownloadingTo, to: URL(fileURLWithPath: self.downloadItemDestination))
            print("Successfuly moved \(didFinishDownloadingTo) to \(self.downloadItemDestination)")
            } catch {
            fatalError("Error moving file from \(didFinishDownloadingTo) to \(self.downloadItemDestination), error:\n\(error)\nExiting..")
        }
        sema.signal()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let totalBytesWrittenFormatted = formatBytes(totalBytesWritten)
        let totalBytesExpectedToWriteFormatted = formatBytes(totalBytesExpectedToWrite)

        print("Downloaded \(totalBytesWrittenFormatted) out of \(totalBytesExpectedToWriteFormatted)", terminator: "\r")
        fflush(stdout)
    }
}

