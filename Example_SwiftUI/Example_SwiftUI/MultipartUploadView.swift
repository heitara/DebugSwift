//
//  MultipartUploadView.swift
//  Example_SwiftUI
//
//  Created by Emil Atanasov on 07/12/24.
//
// Server to test: https://github.com/heitara/debugswift-strapi-server

import SwiftUI
import Alamofire

struct MultipartUploadView: View {
    let API_BASE_URL = "http://192.168.0.1:1337"
    var body: some View {
        Button {
            Task {
                await uploadFile { progress in
                    print("Uploading.... \(progress)")
                }
            }
        } label: {
            Text("Create Article")
        }
    }

    private func uploadFile(reportProgress: ((Double) -> Void)?) async {
        do {
            guard let jpgPath = Bundle.main.path(forResource: "_6cd8cadc-4a13-4510-9b16-261b6c7d2117", ofType: "jpg") else {
                print("JPG file not found in the app bundle.")
                return
            }

            guard let jpgData = try? Data(contentsOf: URL(fileURLWithPath: jpgPath)) else {
                print("JPG data CAN'T be loaded successfully.")
                return
            }

            let params = MultipartFormData()
            let extraInfo = "{\"title\":\"Sample article\", \"body\":\" Created from iOS app\"}"
            if let data = "\(extraInfo)".data(using: .utf8) {
                params.append(data, withName: "data")
            }

            params.append(jpgData, withName: "files.assets", fileName: "piramids.jpg", mimeType: "image/jpeg")

            let data = try await upload(path: "/api/articles", formData: params) { progress in
                reportProgress?(progress)
            }
            data.debug()
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }

    private func upload(path: String, formData: MultipartFormData, reportProgress: ((Double) -> Void)? = nil) async throws -> Data {
        let commonHeaders: HTTPHeaders = [:]

        return try await withCheckedThrowingContinuation { continuation in
            AF.upload(
                multipartFormData: formData,
                to: API_BASE_URL + path,
                headers: commonHeaders,
                requestModifier: { $0.timeoutInterval = 90 }
            )
            .uploadProgress { progress in
                DispatchQueue.main.async {
                    reportProgress?(progress.fractionCompleted)
                }
            }
            .responseData { response in
                switch response.result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: self.handleError(error: error))
                }
            }
        }
    }

    private func handleError(error: AFError) -> Error {
        if let underlyingError = error.underlyingError {
            let nsError = underlyingError as NSError
            let code = nsError.code
            if code == NSURLErrorNotConnectedToInternet
                || code == NSURLErrorTimedOut
                || code == NSURLErrorInternationalRoamingOff
                || code == NSURLErrorDataNotAllowed
                || code == NSURLErrorCannotFindHost
                || code == NSURLErrorCannotConnectToHost
                || code == NSURLErrorNetworkConnectionLost {
                var userInfo = nsError.userInfo
                userInfo[NSLocalizedDescriptionKey] = "Unable to connect to the server"
                let currentError = NSError(
                    domain: nsError.domain,
                    code: code,
                    userInfo: userInfo
                )
                return currentError
            }
        }
        return error
    }
}

#Preview {
    MultipartUploadView()
}
