import Foundation
import ArgumentParser
import plate

enum Environment: String {
    case apikey = "MAILER_API_KEY" 
    case apiURL = "MAILER_API_BASE_URL"
    case endpoint = "MAILER_API_ENDPOINT_DEFAULT"
    case from = "MAILER_FROM"
    case alias = "MAILER_ALIAS"
    case aliasInvoice = "MAILER_ALIAS_INVOICE"
    case domain = "MAILER_DOMAIN"
    case replyTo = "MAILER_REPLY_TO"
    case invoiceJSON = "MAILER_INVOICE_JSON"
    case invoicePDF = "MAILER_INVOICE_PDF"
    case testEmail = "MAILER_TEST_EMAIL"
    case automationsEmail = "MAILER_AUTOMATIONS_EMAIL"
}

struct From {
    let name: String
    let alias: String
    let domain: String

    init(name: String, alias: String, domain: String) {
        self.name = name
        self.alias = alias
        self.domain = domain
    }

    func dictionary() -> [String: String] {
        return [
            "name": name,
            "alias": alias,
            "domain": domain
        ]
    } 
}

struct To {
    let to: [String]
    let cc: [String]
    let bcc: [String]
    
    func dictionary() -> [String: [String]] {
        return [
            "to": to,
            "cc": cc,
            "bcc": bcc
        ]
    } 
}

struct Template {
    let category: String
    let file: String
    let variables: [String: String]

    init(category: String, file: String, variables: [String: String]) {
        self.category = category
        self.file = file
        self.variables = variables
    }

    func dictionary() -> [String: Any] {
        return [
            "category": category,
            "file": file,
            "variables": variables
        ]
    }
}

enum FileType: String {
    case pdf = "pdf"
    case jpg = "jpg"
    case png = "png"
    case txt = "txt"
    case json = "json"
    case unknown = "unknown"
    
    static func from(extension ext: String) -> FileType {
        return FileType(rawValue: ext.lowercased()) ?? .unknown
    }
}

struct Attachment {
    let path: String
    let type: FileType
    let value: String
    let name: String

    init(path: String, type: FileType? = nil, name: String? = nil) {
        self.path = path
        self.value = (try? Data(contentsOf: URL(fileURLWithPath: path)).base64EncodedString()) ?? ""
        let fileExtension = (path as NSString).pathExtension
        self.type = type ?? FileType.from(extension: fileExtension)
        
        self.name = name ?? (path as NSString).lastPathComponent
    }

    func dictionary() -> [String: String] {
        return [
            "type": type.rawValue,
            "value": value,
            "name": name
        ]
    }
}

struct Attachments {
    private(set) var attachments: [Attachment] = []

    init() {}

    init(attachments: [Attachment]) {
        self.attachments = attachments
    }

    mutating func add(_ attachment: Attachment) {
        attachments.append(attachment)
    }

    mutating func add(_ attachmentsArray: [Attachment]) {
        for i in attachmentsArray {
            attachments.append(i)
        }
    }

    mutating func add(from paths: [String], type: FileType) {
        for path in paths {
            let fileName = (path as NSString).lastPathComponent
            let attachment = Attachment(path: path, type: type, name: fileName)
            attachments.append(attachment)
        }
    }

    func array() -> [[String: String]] {
        return attachments.map { $0.dictionary() }
    }
}

struct EmailBody {
    let from: From
    let to: To
    let subject: String
    let template: Template
    let headers: [String: String]
    let replyTo: [String]
    let attachments: [Attachment]
} 

struct Mailer: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mailer",
        abstract: "Mailer api interface",
        version: "1.0.0",
        subcommands: [Mail.self, Invoice.self, Confirmation.self, Follow.self, Onboarding.self],  
        defaultSubcommand: Mail.self
    )
}

func reqURL(apiURL: String? = nil, endpoint: String? = nil) throws -> URL {
    let resolvedAPIURL = apiURL ?? environment(Environment.apiURL.rawValue)
    let resolvedEndpoint = endpoint ?? environment(Environment.endpoint.rawValue)
    
    let urlString = "\(resolvedAPIURL)/\(resolvedEndpoint)"
    
    guard let url = URL(string: urlString) else {
        throw URLError(.badURL, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
    }

    return url
}

struct Mail: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mail",
        abstract: "Base function to send email with custom from and to inputs"
    )

    @Option(name: .shortAndLong, help: "API base URL (defaults to env var)")
    var apiURL: String = environment(Environment.apiURL.rawValue)

    @Option(name: .shortAndLong, help: "API access key (defaults to env var)")
    var apikey: String = environment(Environment.apikey.rawValue)

    @Option(name: .shortAndLong, help: "API endpoint (defaults to env var)")
    var endpoint: String = environment(Environment.endpoint.rawValue)

    @Option(name: .shortAndLong, help: "From name")
    var from: String = environment(Environment.from.rawValue)

    @Option(name: .shortAndLong, help: "From alias: (alias -> alias@domain.nl)")
    var alias: String = environment(Environment.alias.rawValue)

    @Option(name: .shortAndLong, help: "From domain (domain.nl)")
    var domain: String = environment(Environment.domain.rawValue)

    @Option(name: .shortAndLong, parsing: .unconditional, help: "Recipient email address(es)")
    var to: String

    @Option(name: .shortAndLong, parsing: .unconditional, help: "CC email addresses (comma-separated)")
    var cc: String = ""

    @Option(name: .shortAndLong, parsing: .unconditional, help: "BCC email addresses (comma-separated)")
    var bcc: String = ""

    @Option(name: .shortAndLong, help: "Email subject")
    var subject: String?

    @Option(name: .shortAndLong, help: "HTML template category (server-side)")
    var category: String 

    @Option(name: .shortAndLong, help: "HTML template file in category (server-side)")
    var file: String 

    @Option(name: .shortAndLong, parsing: .unconditional, help: "Comma-separated key=value pairs for template replacement")
    var variables: String

    @Option(name: .shortAndLong, parsing: .unconditional, help: "Headers to include")
    var headers: String?

    @Option(name: .shortAndLong, parsing: .unconditional, help: "Body for request")
    var body: String?

    @Option(name: .shortAndLong, parsing: .unconditional, help: "Comma-separated file paths for attachments")
    var attachments: String?

    @Option(name: .shortAndLong, parsing: .unconditional, help: "Reply to addresses")
    var replyTo: String = environment(Environment.replyTo.rawValue)

    @Option(name: .shortAndLong, help: "Log debugging")
    var log: Bool = false

    func run() throws {
        let from = From(name: from, alias: alias, domain: domain)

        let toEmails = to.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let ccEmails = cc.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let bccEmails = bcc.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        let to = To(to: toEmails, cc: ccEmails, bcc: bccEmails)

        let variablesDict = parseKeyValues(variables)
        let template = Template(category: category, file: file, variables: variablesDict)

        let attachmentsSet = parseAttachments(attachments ?? "")

        let emailbody = EmailBody(
            from: from,
            to: to,
            subject: subject ?? "",
            template: template,
            headers: parseKeyValues(headers ??  ""),
            replyTo: parseList(replyTo),
            attachments: attachmentsSet
        )

        // let bodyData = body.data(using: .utf8)
        let bodyData = constructBody(emailbody)

        let req = NetworkRequest(
            url: try reqURL(),
            method: .post,
            auth: .apikey(value: apikey),
            headers: parseKeyValues(headers ?? ""),
            body: bodyData,
            log: log
        )

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        req.execute { success, data, error in
            defer { dispatchGroup.leave() }

            if let error = error {
                print("API ERROR:\n\(error)".ansi(.red))
            } else if let data = data, success {
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("API Response:\n\(responseString)".ansi(.green))
            } else {
                print("Unknown failure.")
            }
        }

        dispatchGroup.wait() 
    }

    func parseAttachments(_ string: String) -> [Attachment] {
        let paths = string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let attachments = paths.map { Attachment(path: $0) }
        return attachments
    }

    func parseList(_ string: String) -> [String] {
        return string
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    func parseKeyValues(_ string: String) -> [String: String] {
        guard string != "" else { return [:] }

        var dictionary: [String: String] = [:]

        string.split(separator: ",").forEach { string in
            let components = string.split(separator: "=", maxSplits: 1).map { String($0) }
            if components.count == 2 {
                dictionary[components[0].trimmingCharacters(in: .whitespaces)] =
                    components[1].trimmingCharacters(in: .whitespaces)
            }
        }

        return dictionary
    }

    func constructBody(_ emailbody: EmailBody) -> Data? {
        var body: [String: Any] = [
            "from": emailbody.from.dictionary(),
            "to": emailbody.to.to,
            "cc": emailbody.to.cc.isEmpty ? nil : emailbody.to.cc,  
            "bcc": emailbody.to.bcc.isEmpty ? nil : emailbody.to.bcc,
            "template": emailbody.template.dictionary(),
            "replyTo": emailbody.replyTo.isEmpty ? nil : emailbody.replyTo,
            "headers": emailbody.headers.isEmpty ? nil : emailbody.headers,
            "attachments": emailbody.attachments.isEmpty ? nil : emailbody.attachments.map { $0.dictionary() }
        ]

        if !emailbody.subject.isEmpty {
            body["subject"] = emailbody.subject
        }

        body = body.compactMapValues { $0 }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Generated JSON Body:\n\(jsonString)")
            }
            return jsonData
        } catch {
            print("Error serializing JSON: \(error)")
            return nil
        }
    }
}

struct Invoice: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "invoice",
        abstract: "Send invoice based on numbers-parser"
    )

    @Option(name: .shortAndLong, parsing: .unconditional, help: "Comma-separated file paths for attachments")
    var close: Bool = false

    @Option(name: [.short, .long, .customLong("id")], parsing: .unconditional, help: "Comma-separated file paths for attachments")
    var invoiceId: String

    func run() throws {
        do {
            try executeNumbersParser(invoiceId: invoiceId, close: close)
            let invoiceData = try readParsedInvoiceData(invoiceId: invoiceId)
            let mailPayload = constructMailPayload(from: invoiceData)
            try sendInvoiceEmail(payload: mailPayload)
        } catch {
            print("Error running commands: \(error)")
        }
    }

    func executeNumbersParser(invoiceId: String, close: Bool) throws {
        do {
            let home = Home.string()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh") // Use Zsh directly
            process.arguments = ["-c", "source ~/.zprofile && \(home)/sbm-bin/numbers-parser --close \(close) --adjust-before-exporting --value \(invoiceId)"]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            try process.run()
            process.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let outputString = String(data: outputData, encoding: .utf8) ?? ""
            let errorString = String(data: errorData, encoding: .utf8) ?? ""

            if process.terminationStatus == 0 {
                print("numbers-parser executed successfully:\n\(outputString)")
            } else {
                print("Error running numbers-parser:\n\(errorString)")
                throw NSError(domain: "numbers-parser", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorString])
            }
        } catch {
            print("Error running commands: \(error)")
            throw error
        }
    }

   func readParsedInvoiceData(invoiceId: String) throws -> [String: String] {
        let jsonFilePath = environment(Environment.invoiceJSON.rawValue)

        guard FileManager.default.fileExists(atPath: jsonFilePath) else {
            throw NSError(domain: "InvoiceError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Parsed invoice JSON not found: \(jsonFilePath)"])
        }

        let jsonData = try Data(contentsOf: URL(fileURLWithPath: jsonFilePath))
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])

        guard let rootDict = jsonObject as? [String: Any],
              let invoicesDict = rootDict["Invoices"] as? [String: String]
        else {
            throw NSError(domain: "InvoiceError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure in \(jsonFilePath)"])
        }

        print("Successfully extracted invoice data:\n\(invoicesDict)")
        return invoicesDict
    }

    func constructMailPayload(from invoiceData: [String: Any]) -> [String: Any] {
        let name = invoiceData["client_name"] as? String ?? "Unknown"
        let email = invoiceData["client_email"] as? String ?? "Unknown"
        let invoiceNumber = invoiceData["invoice_id"] as? String ?? "000000"
        let dueDate = invoiceData["due_date"] as? String ?? "N/A"
        let productLine = invoiceData["product_line"] as? String ?? "N/A"
        let amount = invoiceData["revenue_amount"] as? String ?? "0.00"
        let total = invoiceData["amount"] as? String ?? "0.00"
        let vatPercentage = invoiceData["vat_percentage"] as? String ?? "0.00"
        let vatAmount = invoiceData["vat_amount"] as? String ?? "0.00"
        // let paymentLink = invoiceData["payment_link"] as? String ?? "https://test.nl"

        let accountValue = invoiceData["account_value"] as? String ?? "0.00"
        let accountFulfilled = invoiceData["account_fulfilled"] as? String ?? "0.00"
        let termsTotal = invoiceData["terms_total"] as? String ?? "0"
        let termsCurrent = invoiceData["terms_current"] as? String ?? "0"

        let attachmentPath = environment(Environment.invoicePDF.rawValue)
        let attachmentURL = URL(fileURLWithPath: attachmentPath)
        let attachmentBase64 = attachmentURL.base64()
        
        let sendEmail = environment(Environment.testEmail.rawValue)

        print()
        print("Sending to: \(sendEmail)".ansi(.bold))
        print()

        return [
            "from": [
                "name": environment(Environment.from.rawValue),
                "alias": environment(Environment.aliasInvoice.rawValue),
                "domain": environment(Environment.domain.rawValue)
            ],
            // "to": [email],
            "to": [sendEmail],
            "bcc": environment(Environment.automationsEmail.rawValue),
            // "subject": "Betalingsherinnering",
            "template": [
                "category": "invoice",
                "file": "issue",
                "variables": [
                    "name": name,
                    "email": sendEmail,
                    "invoice_number": invoiceNumber,
                    "due_date": dueDate,
                    "amount": amount,
                    "vat_amount": vatAmount,
                    "vat_percentage": vatPercentage,
                    "total": total,
                    "product_line": productLine,
                    "terms_total": termsTotal,
                    "terms_current": termsCurrent
                ]
            ],
            "replyTo": [environment(Environment.replyTo.rawValue)],
            "attachments": [
                [
                    "type": "pdf",
                    "value": attachmentBase64 ?? "",
                    "name": "factuur-\(invoiceNumber).pdf"
                ]
            ]
        ]
    }

    func sendInvoiceEmail(payload: [String: Any]) throws {
        let apiKey = environment(Environment.apikey.rawValue)
        let reqURL = try reqURL()
        print("Hitting API endpoint with URL: ", reqURL)

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let request = NetworkRequest(
            url: reqURL,
            method: .post,
            auth: .apikey(value: apiKey),
            headers: ["Content-Type": "application/json"],
            body: jsonData,
            log: true
        )

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        request.execute { success, data, error in
            defer { dispatchGroup.leave() }

            if let error = error {
                print("Error sending email:\n\(error)".ansi(.red))
            } else if let data = data, success {
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Email sent successfully:\n\(responseString)".ansi(.green))
            }
        }

        dispatchGroup.wait()
    }
}

struct Confirmation: ParsableCommand {
    @Option(name: .shortAndLong, parsing: .unconditional, help: "Comma-separated file paths for attachments")
    var invoiceId: String

    func run() throws {

    }
}

struct Follow: ParsableCommand {
    @Option(name: .shortAndLong, parsing: .unconditional, help: "Comma-separated file paths for attachments")
    var invoiceId: String

    func run() throws {

    }
}

struct Onboarding: ParsableCommand {
    @Option(name: .shortAndLong, parsing: .unconditional, help: "Comma-separated file paths for attachments")
    var invoiceId: String

    func run() throws {

    }
}

Mailer.main()
