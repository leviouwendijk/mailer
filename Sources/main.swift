import Foundation
import ArgumentParser
import plate

let production = true

enum Environment: String {
    case apikey = "MAILER_API_KEY" 
    case apiURL = "MAILER_API_BASE_URL"
    case endpoint = "MAILER_API_ENDPOINT_DEFAULT"
    case from = "MAILER_FROM"
    case alias = "MAILER_ALIAS"
    case aliasInvoice = "MAILER_ALIAS_INVOICE"
    case aliasAppointment = "MAILER_ALIAS_APPOINTMENT"
    case domain = "MAILER_DOMAIN"
    case replyTo = "MAILER_REPLY_TO"
    case invoiceJSON = "MAILER_INVOICE_JSON"
    case invoicePDF = "MAILER_INVOICE_PDF"
    case testEmail = "MAILER_TEST_EMAIL"
    case automationsEmail = "MAILER_AUTOMATIONS_EMAIL"
    case quotePath = "MAILER_QUOTE_PATH"
}

enum Route: String, RawRepresentable {
    case send
    case invoice
    case appointment
    case quote
    case lead
    case service
    case resolution
    case affiliate
    case custom
    case template

    func alias() -> String {
        switch self {
            case .send:
                return "relaties"
            case .invoice:
                return "betalingen"
            case .appointment:
                return "bevestigingen"
            case .quote:
                return "offertes"
            case .lead:
                return "relaties"
            case .service:
                return "relaties"
            case .resolution:
                return "relaties"
            case .affiliate:
                return "relaties"
            case .custom:
                return "relaties"
            default:
                return "relaties"
        }
    }
}

enum Endpoint: String, RawRepresentable {
    case new = "new"
    case issue = "issue"
    case issueSimple = "issue/simple"
    case expired = "expired"
    case confirmation = "confirmation"
    case reminder = "reminder"
    case follow = "follow"
    case onboarding = "onboarding"
    case review = "review"
    case check = "check"
    case food = "food"
    case fetch = "fetch"
    case messageSend = "message/send"
    case demo = "demo"
}

struct RequestURL {
    let route: Route
    let endpoint: Endpoint

    init(route: Route, endpoint: Endpoint) {
        self.route = route
        self.endpoint = endpoint
    }

    func url() -> URL {
        let base = environment(Environment.apiURL.rawValue)
        let urlString = "\(base)/\(route.rawValue)/\(endpoint.rawValue)"
        return URL(string: urlString) ?? URL(string: "https://error.com")!
    }

    func string() -> String {
        let base = environment(Environment.apiURL.rawValue)
        let urlString = "\(base)/\(route.rawValue)/\(endpoint.rawValue)"
        return urlString
    }
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
    let variables: [String: Any]

    init(category: String, file: String, variables: [String: Any]) {
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

struct AppointmentDetails: Codable {
    let date: String
    let time: String
    let day: String
    let street: String
    let number: String
    let area: String
    let location: String
}

struct AvailabilityEntry: Codable {
    let start: String
    let end:   String
}

struct Mailer: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mailer",
        abstract: "Mailer api interface",
        version: "1.0.0",
        subcommands: [Invoice.self, Appointment.self, Quote.self, Service.self, Resolution.self, Lead.self, Affiliate.self, TemplateAPI.self, CustomMessage.self, Example.self]  
        // defaultSubcommand: Mail.self
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

struct Invoice: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "invoice",
        abstract: "Send invoice based on numbers-parser"
    )

    @Option(name: .shortAndLong, parsing: .unconditional, help: "Close specifier to pass to numbers-parser (closes file after export if explicitly set to 'true')")
    var close: Bool = false

    @Argument(help: "Invoice ID as in .numbers")
    var invoiceId: String

    @Flag(name: .shortAndLong, help: "Changes endpoint from /invoice/issue to /invoice/expired")
    var expired: Bool = false

    @Flag(name: .shortAndLong, help: "Return to Responder instead of Ghostty in numbers-parser")
    var responder: Bool = false

    func run() throws {
        do {
            try executeNumbersParser(invoiceId: invoiceId, close: close, returnToResponder: responder)
            let invoiceData = try readParsedInvoiceData(invoiceId: invoiceId)
            let mailPayload = try constructMailPayload(from: invoiceData)
            try sendInvoiceEmail(payload: mailPayload, expired: expired)
        } catch {
            print("Error running commands: \(error)")
        }
    }

    func executeNumbersParser(invoiceId: String, close: Bool, returnToResponder: Bool) throws {
        do {
            let home = Home.string()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh") // Use Zsh directly

            let base = "source ~/.zprofile && \(home)/sbm-bin/numbers-parser --close \(close) --adjust-before-exporting --value \(invoiceId)"
            let cmd = returnToResponder ? base + " --responder" : base

            process.arguments = ["-c", cmd]
            
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

    func constructMailPayload(from invoiceData: [String: Any]) throws -> [String: Any] {
        let name = invoiceData["client_name"] as? String ?? "Unknown"
        let email = invoiceData["email"] as? String ?? "ERROR EXTRACTING EMAIL FROM numbers-parser/client_db_reparse.json"
        let invoiceNumber = invoiceData["invoice_id"] as? String ?? "000000"
        let dueDate = invoiceData["due_date"] as? String ?? "N/A"
        let productLine = invoiceData["product_line"] as? String ?? "N/A"
        let amount = invoiceData["revenue_amount"] as? String ?? "0.00"
        let total = invoiceData["amount"] as? String ?? "0.00"
        let vatPercentage = invoiceData["vat_percentage"] as? String ?? "0.00"
        let vatAmount = invoiceData["vat_amount"] as? String ?? "0.00"
        // let paymentLink = invoiceData["payment_link"] as? String ?? "https://test.nl"

        // let accountValue = invoiceData["account_value"] as? String ?? "0.00"
        // let accountFulfilled = invoiceData["account_fulfilled"] as? String ?? "0.00"
        let termsTotal = invoiceData["terms_total"] as? String ?? "0"
        let termsCurrent = invoiceData["terms_current"] as? String ?? "0"

        let attachmentPath = environment(Environment.invoicePDF.rawValue)
        let attachmentURL = URL(fileURLWithPath: attachmentPath)
        let attachmentBase64 = try attachmentURL.base64()
        
        let sendEmail = production ? email : environment(Environment.testEmail.rawValue)

        print()
        print("Sending to: \(sendEmail)".ansi(.bold))
        print()

        return [
            "from": [
                "name": environment(Environment.from.rawValue),
                "alias": Route.invoice.alias(),
                "domain": environment(Environment.domain.rawValue)
            ],
            // "to": [email],
            // "to": [sendEmail],
            "to": sendEmail,
            "bcc": environment(Environment.automationsEmail.rawValue),
            // "subject": "Betalingsherinnering",
            "template": [
                // "category": "invoice",
                // "file": "issue",
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

    func sendInvoiceEmail(payload: [String: Any], expired: Bool = false) throws {
        let apiKey = environment(Environment.apikey.rawValue)

        var endpoint: URL

        if expired {
            endpoint = RequestURL(
                route: .invoice,
                endpoint: .expired
            ).url()
        } else {
            endpoint = RequestURL(
                route: .invoice,
                endpoint: .issue
            ).url()
        }

        print("Hitting API endpoint with URL: ", endpoint)

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let request = NetworkRequest(
            url: endpoint,
            method: .post,
            auth: .apikey(value: apiKey),
            headers: ["Content-Type": "application/json"],
            body: jsonData,
            log: true
        )

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        // request.execute { success, data, error in
        //     defer { dispatchGroup.leave() }

        //     if let error = error {
        //         print("Error sending email:\n\(error)".ansi(.red))
        //     } else if let data = data, success {
        //         let responseString = String(data: data, encoding: .utf8) ?? "No response data"
        //         print("Email sent successfully:\n\(responseString)".ansi(.green))
        //     }
        // }

        request.executeAPI { result in
            switch result {
            case .success(let data):
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Email sent successfully:\n\(responseString)".ansi(.green))

            case .failure(let apiErr):
                // Print the server‐returned error JSON if you like,
                // otherwise just show apiErr.message
                if let errData = try? JSONEncoder().encode(apiErr),
                    let errJSON = String(data: errData, encoding: .utf8) {
                        print("Error sending email:\n\(errJSON)".ansi(.red))
                    } else {
                        print("Error sending email:\n\(apiErr.message)".ansi(.red))
                    }
            }
            dispatchGroup.leave()
        }

        dispatchGroup.wait()
    }
}

struct Appointment: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appointment",
        abstract: "Send an appointment confirmation email"
    )

    @Option(name: .shortAndLong, help: "Client name")
    var client: String

    @Option(name: .shortAndLong, help: "Dog's name")
    var dog: String

    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "email address to send to")
    var email: [String] = []

    @Argument(help: "JSON array of appointments")
    var appointmentsJSON: String

    func run() throws {
        guard let data = appointmentsJSON.data(using: .utf8),
              var appointments = try? JSONDecoder().decode([AppointmentDetails].self, from: data) else {
            throw ValidationError("Invalid JSON format for appointments")
        }

        // **Sort appointments by date & time**
        appointments.sort { (a, b) -> Bool in
            guard let dateA = parseDateTime(date: a.date, time: a.time),
                  let dateB = parseDateTime(date: b.date, time: b.time) else { return false }
            return dateA < dateB
        }

        var appointmentEntries: [[String: String]] = []
        var attachments: [[String: String]] = []

        for appointment in appointments {
            let icsContent = generateICS(client: client, dog: dog, appointment: appointment)
            let icsBase64 = Data(icsContent.utf8).base64EncodedString()

            appointmentEntries.append([
                "date": appointment.date,
                "time": appointment.time,
                "day": appointment.day,
                "street": appointment.street,
                "number": appointment.number,
                "area": appointment.area,
                "location": appointment.location
            ])

            attachments.append([
                "name": "appointment-\(appointment.date)-\(dog).ics",
                "value": icsBase64,
                "type": "text/calendar"
            ])
        }

        let mailPayload: [String: Any] = [
            "from": [
                "name": environment(Environment.from.rawValue),
                "alias": Route.appointment.alias(),
                "domain": environment(Environment.domain.rawValue)
            ],
            // "to": [email],
            "to": email,
            "bcc": environment(Environment.automationsEmail.rawValue),
            "template": [
                // "category": "appointment",
                // "file": "confirmation",
                "variables": [
                    "name": client,
                    "dog": dog,
                    "appointments": appointmentEntries
                ]
            ],
            "replyTo": [environment(Environment.replyTo.rawValue)],
            "attachments": attachments
        ]

        try sendAppointmentEmail(payload: mailPayload)
    }

    /// Function to generate ICS file content
    func generateICS(client: String, dog: String, appointment: AppointmentDetails) -> String {
        let startTime = convertToICSFormat(date: appointment.date, time: appointment.time, timeType: "start")
        let endTime = convertToICSFormat(date: appointment.date, time: appointment.time, timeType: "end")

        return """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Hondenmeesters//Event Confirmation//EN
        BEGIN:VEVENT
        UID:\(UUID().uuidString)@hondenmeesters.nl
        DTSTAMP:\(isoTimestamp())
        DTSTART:\(startTime)
        DTEND:\(endTime)
        SUMMARY:Hondenmeesters, afspraak voor \(dog)
        DESCRIPTION:Beste \(client),\\n\\nJe afspraak voor \(dog) is bevestigd.\\n\\nHoud alsjeblieft rekening met mogelijke uitloop.\\n\\nHartelijke groet,\\nHet Hondenmeesters Team
        LOCATION:\(appointment.street) \(appointment.number)\\n\(appointment.area)\\n\(appointment.location)
        END:VEVENT
        END:VCALENDAR
        """
    }
    
    func convertToICSFormat(date: String, time: String, timeType: String, duration: Double = 2.0.hoursToSeconds()) -> String {
        guard let dateTime = parseDateTime(date: date, time: time) else {
            return "ERROR_DATE_FORMAT"
        }

        let finalTime = (timeType == "end") ? dateTime.addingTimeInterval(duration) : dateTime

        return formatDateToICS(finalTime)
    }

    /// Parses date and time strings into a `Date` object
    func parseDateTime(date: String, time: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return formatter.date(from: "\(date) \(time)")
    }

    /// Converts a `Date` object to ICS-compliant UTC format
    func formatDateToICS(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    /// Function to get the current timestamp in ICS format
    func isoTimestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    /// Function to send the appointment email
    func sendAppointmentEmail(payload: [String: Any]) throws {
        let apiKey = environment(Environment.apikey.rawValue)
        let endpoint = RequestURL(
            route: .appointment,
            endpoint: .confirmation
        ).url()
        print("Hitting API endpoint with URL: ", endpoint)

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let request = NetworkRequest(
            url: endpoint,
            method: .post,
            auth: .apikey(value: apiKey),
            headers: ["Content-Type": "application/json"],
            body: jsonData,
            log: true
        )

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        // request.execute { success, data, error in
        //     defer { dispatchGroup.leave() }

        //     if let error = error {
        //         print("Error sending email:\n\(error)".ansi(.red))
        //     } else if let data = data, success {
        //         let responseString = String(data: data, encoding: .utf8) ?? "No response data"
        //         print("Email sent successfully:\n\(responseString)".ansi(.green))
        //     }
        // }

        request.executeAPI { result in
            switch result {
            case .success(let data):
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Email sent successfully:\n\(responseString)".ansi(.green))

            case .failure(let apiErr):
                // Print the server‐returned error JSON if you like,
                // otherwise just show apiErr.message
                if let errData = try? JSONEncoder().encode(apiErr),
                    let errJSON = String(data: errData, encoding: .utf8) {
                        print("Error sending email:\n\(errJSON)".ansi(.red))
                    } else {
                        print("Error sending email:\n\(apiErr.message)".ansi(.red))
                    }
            }
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
    }
}

struct Lead: ParsableCommand {
    @Option(name: .shortAndLong, parsing: .unconditional, help: "client name")
    var client: String

    @Option(name: .shortAndLong, parsing: .unconditional, help: "dog name")
    var dog: String

    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "email address to send to")
    var email: [String] = []

    // defaults to "onboarding"
    @Flag(name: .shortAndLong, help: "Follow-up endpoint rather than issue endpoint.")
    var follow: Bool = false

    @Flag(name: .shortAndLong, help: "Check-in email after contact but no next steps taken")
    var check: Bool = false

    @Option(
      name: .long,
      parsing: .unconditional,
      help: "JSON object of availability, e.g. '{\"mon\":{\"start\":\"18:00\",\"end\":\"21:00\"},…}'"
    )
    var availabilityJSON: String

    func run() throws {
        // decode your JSON into a [String:TimeEntry]
        guard let data = availabilityJSON.data(using: .utf8),
              let avail = try? JSONDecoder().decode(
                 [String: AvailabilityEntry].self,
                 from: data
              )
        else {
          throw ValidationError("Invalid JSON for --availabilityJSON")
        }

        let timeRangeDict = avail.reduce(into: [String:[String:String]]()) { out, pair in
            let (day, entry) = pair
                out[day] = ["start": entry.start, "end": entry.end]
        }

        var attachments: [[String: String]] = []

        // let attachmentPath = environment(Environment.quotePath.rawValue)
        // let attachmentURL = URL(fileURLWithPath: attachmentPath)
        // let attachmentBase64 = attachmentURL.base64()

        // if !follow {
        // // for quote in quotes {
        //     attachments.append([
        //         "type": "pdf",
        //         "value": attachmentBase64 ?? "",
        //         "name": "offerte.pdf"
        //     ])
        // // }
        // }

        let mailPayload: [String: Any] = [
            "from": [
                "name": environment(Environment.from.rawValue),
                "alias": Route.lead.alias(),
                "domain": environment(Environment.domain.rawValue)
            ],
            // "to": [email],
            "to": email,
            "bcc": environment(Environment.automationsEmail.rawValue),
            "template": [
                "variables": [
                    "name": client,
                    "dog": dog,
                    "time_range": timeRangeDict
                ]
            ],
            "replyTo": [environment(Environment.replyTo.rawValue)],
            "attachments": attachments
        ]

        try sendLeadEmail(payload: mailPayload, follow: follow, check: check)
    }

    func sendLeadEmail(payload: [String: Any], follow: Bool = false, check: Bool = false) throws {
        let apiKey = environment(Environment.apikey.rawValue)
        
        var endpoint: URL

        if check {
            endpoint = RequestURL(
                route: .lead,
                endpoint: .check
            ).url()
        } else if follow {
            endpoint = RequestURL(
                route: .lead,
                endpoint: .follow
            ).url()
        } else {
            endpoint = RequestURL(
                route: .lead,
                endpoint: .confirmation
            ).url()
        }

        print("Hitting API endpoint with URL: ", endpoint)

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let request = NetworkRequest(
            url: endpoint,
            method: .post,
            auth: .apikey(value: apiKey),
            headers: ["Content-Type": "application/json"],
            body: jsonData,
            log: true
        )

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        request.executeAPI { result in
            switch result {
            case .success(let data):
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Email sent successfully:\n\(responseString)".ansi(.green))

            case .failure(let apiErr):
                if let errData = try? JSONEncoder().encode(apiErr),
                    let errJSON = String(data: errData, encoding: .utf8) {
                        print("Error sending email:\n\(errJSON)".ansi(.red))
                    } else {
                        print("Error sending email:\n\(apiErr.message)".ansi(.red))
                    }
            }
            dispatchGroup.leave()
        }

        dispatchGroup.wait()
    }
}

struct Quote: ParsableCommand {
    @Option(name: .shortAndLong, parsing: .unconditional, help: "client name")
    var client: String

    @Option(name: .shortAndLong, parsing: .unconditional, help: "dog name")
    var dog: String

    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "email address to send to")
    var email: [String] = []

    @Flag(name: .shortAndLong, help: "Follow-up endpoint rather than issue endpoint.")
    var follow: Bool = false

    func run() throws {
        var attachments: [[String: String]] = []

        let attachmentPath = environment(Environment.quotePath.rawValue)
        let attachmentURL = URL(fileURLWithPath: attachmentPath)
        let attachmentBase64 = try attachmentURL.base64()

        if !follow {
        // for quote in quotes {
            attachments.append([
                "type": "pdf",
                "value": attachmentBase64 ?? "",
                "name": "offerte.pdf"
            ])
        // }
        }

        let mailPayload: [String: Any] = [
            "from": [
                "name": environment(Environment.from.rawValue),
                "alias": Route.quote.alias(),
                "domain": environment(Environment.domain.rawValue)
            ],
            // "to": [email],
            "to": email,
            "bcc": environment(Environment.automationsEmail.rawValue),
            "template": [
                "variables": [
                    "name": client,
                    "dog": dog
                ]
            ],
            "replyTo": [environment(Environment.replyTo.rawValue)],
            "attachments": attachments
        ]

        try sendQuoteEmail(payload: mailPayload, follow: follow)
    }

    func sendQuoteEmail(payload: [String: Any], follow: Bool = false) throws {
        let apiKey = environment(Environment.apikey.rawValue)
        
        var endpoint: URL

        if follow {
            endpoint = RequestURL(
                route: .quote,
                endpoint: .follow
            ).url()
        } else {
            endpoint = RequestURL(
                route: .quote,
                endpoint: .issue
            ).url()
        }

        print("Hitting API endpoint with URL: ", endpoint)

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let request = NetworkRequest(
            url: endpoint,
            method: .post,
            auth: .apikey(value: apiKey),
            headers: ["Content-Type": "application/json"],
            body: jsonData,
            log: true
        )

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        request.executeAPI { result in
            switch result {
            case .success(let data):
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Email sent successfully:\n\(responseString)".ansi(.green))

            case .failure(let apiErr):
                if let errData = try? JSONEncoder().encode(apiErr),
                    let errJSON = String(data: errData, encoding: .utf8) {
                        print("Error sending email:\n\(errJSON)".ansi(.red))
                    } else {
                        print("Error sending email:\n\(apiErr.message)".ansi(.red))
                    }
            }
            dispatchGroup.leave()
        }

        dispatchGroup.wait()
    }
}

struct Service: ParsableCommand {
    @Option(name: .shortAndLong, parsing: .unconditional, help: "client name")
    var client: String

    @Option(name: .shortAndLong, parsing: .unconditional, help: "dog name")
    var dog: String

    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "email address to send to")
    var email: [String] = []

    // defaults to "onboarding"
    @Flag(name: .shortAndLong, help: "Follow-up endpoint rather than onboarding endpoint.")
    var follow: Bool = false

    @Flag(name: .shortAndLong, help: "Follow-up endpoint rather than onboarding endpoint.")
    var demo: Bool = false

    // @Option(
    //   name: .long,
    //   parsing: .unconditional,
    //   help: "JSON object of availability, e.g. '{\"mon\":{\"start\":\"18:00\",\"end\":\"21:00\"},…}'"
    // )
    // var availabilityJSON: String

    func run() throws {
        // guard let data = availabilityJSON.data(using: .utf8),
        //       let avail = try? JSONDecoder().decode(
        //          [String: AvailabilityEntry].self,
        //          from: data
        //       )
        // else {
        //   throw ValidationError("Invalid JSON for --availabilityJSON")
        // }

        // let timeRangeDict = avail.reduce(into: [String:[String:String]]()) { out, pair in
        //     let (day, entry) = pair
        //         out[day] = ["start": entry.start, "end": entry.end]
        // }

        var attachments: [[String: String]] = []

        // let attachmentPath = environment(Environment.quotePath.rawValue)
        // let attachmentURL = URL(fileURLWithPath: attachmentPath)
        // let attachmentBase64 = attachmentURL.base64()

        // if !follow {
        // // for quote in quotes {
        //     attachments.append([
        //         "type": "pdf",
        //         "value": attachmentBase64 ?? "",
        //         "name": "offerte.pdf"
        //     ])
        // // }
        // }

        let mailPayload: [String: Any] = [
            "from": [
                "name": environment(Environment.from.rawValue),
                "alias": Route.service.alias(),
                "domain": environment(Environment.domain.rawValue)
            ],
            // "to": [email],
            "to": email,
            "bcc": environment(Environment.automationsEmail.rawValue),
            "template": [
                "variables": [
                    "name": client,
                    "dog": dog,
                    // "time_range": timeRangeDict
                ]
            ],
            "replyTo": [environment(Environment.replyTo.rawValue)],
            "attachments": attachments
        ]

        try sendServiceEmail(payload: mailPayload, follow: follow)
    }

    func sendServiceEmail(payload: [String: Any], follow: Bool = false) throws {
        let apiKey = environment(Environment.apikey.rawValue)
        
        var endpoint: URL

        if demo {
            endpoint = RequestURL(
                route: .service,
                endpoint: .demo
            ).url()
        } else if follow {
            endpoint = RequestURL(
                route: .service,
                endpoint: .follow
            ).url()
        } else {
            endpoint = RequestURL(
                route: .service,
                endpoint: .onboarding
            ).url()
        }

        print("Hitting API endpoint with URL: ", endpoint)

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let request = NetworkRequest(
            url: endpoint,
            method: .post,
            auth: .apikey(value: apiKey),
            headers: ["Content-Type": "application/json"],
            body: jsonData,
            log: true
        )

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        request.executeAPI { result in
            switch result {
            case .success(let data):
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Email sent successfully:\n\(responseString)".ansi(.green))

            case .failure(let apiErr):
                if let errData = try? JSONEncoder().encode(apiErr),
                    let errJSON = String(data: errData, encoding: .utf8) {
                        print("Error sending email:\n\(errJSON)".ansi(.red))
                    } else {
                        print("Error sending email:\n\(apiErr.message)".ansi(.red))
                    }
            }
            dispatchGroup.leave()
        }

        dispatchGroup.wait()
    }
}

struct Resolution: ParsableCommand {
    @Option(name: .shortAndLong, parsing: .unconditional, help: "client name")
    var client: String

    @Option(name: .shortAndLong, parsing: .unconditional, help: "dog name")
    var dog: String

    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "email address to send to")
    var email: [String] = []

    // defaults to "onboarding"
    @Flag(name: .shortAndLong, help: "Follow-up endpoint rather than onboarding endpoint.")
    var follow: Bool = false

    func run() throws {
        var attachments: [[String: String]] = []

        // let attachmentPath = environment(Environment.quotePath.rawValue)
        // let attachmentURL = URL(fileURLWithPath: attachmentPath)
        // let attachmentBase64 = attachmentURL.base64()

        // if !follow {
        // // for quote in quotes {
        //     attachments.append([
        //         "type": "pdf",
        //         "value": attachmentBase64 ?? "",
        //         "name": "offerte.pdf"
        //     ])
        // // }
        // }

        let mailPayload: [String: Any] = [
            "from": [
                "name": environment(Environment.from.rawValue),
                "alias": Route.resolution.alias(),
                "domain": environment(Environment.domain.rawValue)
            ],
            // "to": [email],
            "to": email,
            "bcc": environment(Environment.automationsEmail.rawValue),
            "template": [
                "variables": [
                    "name": client,
                    "dog": dog
                ]
            ],
            "replyTo": [environment(Environment.replyTo.rawValue)],
            "attachments": attachments
        ]

        try sendResolutionEmail(payload: mailPayload, follow: follow)
    }

    func sendResolutionEmail(payload: [String: Any], follow: Bool = false) throws {
        let apiKey = environment(Environment.apikey.rawValue)
        
        var endpoint: URL

        if follow {
            endpoint = RequestURL(
                route: .resolution,
                endpoint: .follow
            ).url()
        } else {
            endpoint = RequestURL(
                route: .resolution,
                endpoint: .review
            ).url()
        }

        print("Hitting API endpoint with URL: ", endpoint)

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let request = NetworkRequest(
            url: endpoint,
            method: .post,
            auth: .apikey(value: apiKey),
            headers: ["Content-Type": "application/json"],
            body: jsonData,
            log: true
        )

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        request.executeAPI { result in
            switch result {
            case .success(let data):
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Email sent successfully:\n\(responseString)".ansi(.green))

            case .failure(let apiErr):
                if let errData = try? JSONEncoder().encode(apiErr),
                    let errJSON = String(data: errData, encoding: .utf8) {
                        print("Error sending email:\n\(errJSON)".ansi(.red))
                    } else {
                        print("Error sending email:\n\(apiErr.message)".ansi(.red))
                    }
            }
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
    }
}

struct Affiliate: ParsableCommand {
    @Option(name: .shortAndLong, parsing: .unconditional, help: "client name")
    var client: String

    @Option(name: .shortAndLong, parsing: .unconditional, help: "dog name")
    var dog: String

    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "email address to send to")
    var email: [String] = []

    // defaults to "onboarding"
    // @Flag(name: .shortAndLong, help: "Follow-up endpoint rather than onboarding endpoint.")
    // var follow: Bool = false

    @Flag(name: .shortAndLong, help: "Follow-up endpoint rather than onboarding endpoint.")
    var food: Bool = false

    func run() throws {
        var attachments: [[String: String]] = []

        // let attachmentPath = environment(Environment.quotePath.rawValue)
        // let attachmentURL = URL(fileURLWithPath: attachmentPath)
        // let attachmentBase64 = attachmentURL.base64()

        // if !follow {
        // // for quote in quotes {
        //     attachments.append([
        //         "type": "pdf",
        //         "value": attachmentBase64 ?? "",
        //         "name": "offerte.pdf"
        //     ])
        // // }
        // }

        let mailPayload: [String: Any] = [
            "from": [
                "name": environment(Environment.from.rawValue),
                "alias": Route.affiliate.alias(),
                "domain": environment(Environment.domain.rawValue)
            ],
            // "to": [email],
            "to": email,
            "bcc": environment(Environment.automationsEmail.rawValue),
            "template": [
                "variables": [
                    "name": client,
                    "dog": dog
                ]
            ],
            "replyTo": [environment(Environment.replyTo.rawValue)],
            "attachments": attachments
        ]

        try sendAffiliateEmail(payload: mailPayload, food: food)
    }

    func sendAffiliateEmail(payload: [String: Any], food: Bool = false) throws {
        let apiKey = environment(Environment.apikey.rawValue)
        
        var endpoint: URL

        if food {
            endpoint = RequestURL(
                route: .affiliate,
                endpoint: .food
            ).url()
        } else {
            print("Endpoint not configured or specified")
            return
            // endpoint = RequestURL(
            //     route: .affiliate,
            //     endpoint: .review
            // ).url()
        }

        print("Hitting API endpoint with URL: ", endpoint)

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let request = NetworkRequest(
            url: endpoint,
            method: .post,
            auth: .apikey(value: apiKey),
            headers: ["Content-Type": "application/json"],
            body: jsonData,
            log: true
        )

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        request.executeAPI { result in
            switch result {
            case .success(let data):
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Email sent successfully:\n\(responseString)".ansi(.green))

            case .failure(let apiErr):
                // Print the server‐returned error JSON if you like,
                // otherwise just show apiErr.message
                if let errData = try? JSONEncoder().encode(apiErr),
                    let errJSON = String(data: errData, encoding: .utf8) {
                        print("Error sending email:\n\(errJSON)".ansi(.red))
                    } else {
                        print("Error sending email:\n\(apiErr.message)".ansi(.red))
                    }
            }
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
    }
}

struct TemplateAPI: ParsableCommand {
    @Argument(help: "API server template category")
    var category: String

    @Argument(help: "API server template file, in category")
    var file: String

    func run() throws {
        var attachments: [[String: String]] = []

        let mailPayload: [String: Any] = [
            "template": [
                "variables": [
                    "category": category,
                    "file": file
                ]
            ]
        ]

        try fetch(payload: mailPayload)
    }

    func fetch(payload: [String: Any]) throws {
        let apiKey = environment(Environment.apikey.rawValue)
        
        var endpoint: URL

        endpoint = RequestURL(
            route: .template,
            endpoint: .fetch
        ).url()

        print("Hitting API endpoint with URL: ", endpoint)

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let request = NetworkRequest(
            url: endpoint,
            method: .post,
            auth: .apikey(value: apiKey),
            headers: ["Content-Type": "application/json"],
            body: jsonData,
            log: true
        )

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        request.executeAPI { result in
            switch result {
            case .success(let data):
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Fetched template:\n\(responseString)".ansi(.green))

            case .failure(let apiErr):
                if let errData = try? JSONEncoder().encode(apiErr),
                    let errJSON = String(data: errData, encoding: .utf8) {
                        print("Error fetching template:\n\(errJSON)".ansi(.red))
                    } else {
                        print("Error fetching template:\n\(apiErr.message)".ansi(.red))
                    }
            }
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
    }
}

struct CustomMessage: ParsableCommand {
    @Option(name: .shortAndLong, parsing: .upToNextOption, help: "email address to send to")
    var email: [String] = []

    @Option(name: .shortAndLong, parsing: .unconditional, help: "subject of message")
    var subject: String

    @Option(name: .shortAndLong, parsing: .unconditional, help: "html body")
    var body: String

    @Flag(name: .shortAndLong, help: "Include quote in custom message")
    var quote: Bool = false

    func run() throws {
        var attachments: [[String: String]] = []

        let attachmentPath = environment(Environment.quotePath.rawValue)
        let attachmentURL = URL(fileURLWithPath: attachmentPath)
        let attachmentBase64 = try attachmentURL.base64()

        if quote {
            attachments.append([
                "type": "pdf",
                "value": attachmentBase64,
                "name": "offerte.pdf"
            ])
        }

        let mailPayload: [String: Any] = [
            "from": [
                "name": environment(Environment.from.rawValue),
                "alias": quote ? Route.quote.alias() : Route.custom.alias(),
                "domain": environment(Environment.domain.rawValue)
            ],
            // "to": [email],
            "to": email,
            "bcc": environment(Environment.automationsEmail.rawValue),
            "subject": subject,
            "template": [
                "variables": [
                    "body": body,
                ]
            ],
            "replyTo": [environment(Environment.replyTo.rawValue)],
            "attachments": attachments
        ]

        try sendCustomMessageEmail(payload: mailPayload)
    }

    func sendCustomMessageEmail(payload: [String: Any]) throws {
        let apiKey = environment(Environment.apikey.rawValue)
        
        var endpoint: URL

        endpoint = RequestURL(
            route: .custom,
            endpoint: .messageSend
        ).url()

        print("Hitting API endpoint with URL: ", endpoint)

        let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
        
        let request = NetworkRequest(
            url: endpoint,
            method: .post,
            auth: .apikey(value: apiKey),
            headers: ["Content-Type": "application/json"],
            body: jsonData,
            log: true
        )

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()

        request.executeAPI { result in
            switch result {
            case .success(let data):
                let responseString = String(data: data, encoding: .utf8) ?? "No response data"
                print("Email sent successfully:\n\(responseString)".ansi(.green))

            case .failure(let apiErr):
                // Print the server‐returned error JSON if you like,
                // otherwise just show apiErr.message
                if let errData = try? JSONEncoder().encode(apiErr),
                    let errJSON = String(data: errData, encoding: .utf8) {
                        print("Error sending email:\n\(errJSON)".ansi(.red))
                    } else {
                        print("Error sending email:\n\(apiErr.message)".ansi(.red))
                    }
            }
            dispatchGroup.leave()
        }
        dispatchGroup.wait()
    }
}

struct Example: ParsableCommand {
    func run() throws {
        print()
        print("mailer".ansi(.green) + " " + "invoice".ansi(.underline) + " " + "388".ansi(.italic))
        print()
    }
}

Mailer.main()
