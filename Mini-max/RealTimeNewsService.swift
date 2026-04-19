import Foundation

struct RawNewsItem {
    let title: String
    let source: String
    let date: Date
}

class RealTimeNewsService {
    static let shared = RealTimeNewsService()
    
    private let sources = [
        "TechCrunch": "https://techcrunch.com/feed/",
        "The Verge": "https://www.theverge.com/rss/index.xml",
        "CNN Business": "http://rss.cnn.com/rss/money_latest.rss",
        "BBC Tech": "https://feeds.bbci.co.uk/news/technology/rss.xml",
        "BBC Business": "https://feeds.bbci.co.uk/news/business/rss.xml",
        "Forbes": "https://www.forbes.com/business/feed/",
        "Techmeme": "https://techmeme.com/feed.atom"
    ]
    
    func fetchAll() async -> [RawNewsItem] {
        var allItems: [RawNewsItem] = []
        
        await withTaskGroup(of: [RawNewsItem].self) { group in
            // RSS Sources
            for (name, urlString) in sources {
                group.addTask {
                    return await self.fetchSource(name: name, urlString: urlString)
                }
            }
            
            // JSON Sources (Dev.to)
            group.addTask {
                return await self.fetchDevTo()
            }
            
            for await items in group {
                allItems.append(contentsOf: items)
            }
        }
        
        return allItems.sorted { $0.date > $1.date }
    }
    
    private func fetchDevTo() async -> [RawNewsItem] {
        guard let url = URL(string: "https://dev.to/api/articles?top=1&per_page=5") else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let items = try JSONDecoder().decode([DevToItem].self, from: data)
            return items.map { RawNewsItem(title: $0.title, source: "Dev.to", date: Date()) }
        } catch {
            print("[NewsService] Error fetching Dev.to: \(error)")
            return []
        }
    }

    private struct DevToItem: Decodable {
        let title: String
    }
    
    private func fetchSource(name: String, urlString: String) async -> [RawNewsItem] {
        guard let url = URL(string: urlString) else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return parseRSS(data: data, source: name)
        } catch {
            print("[NewsService] Error fetching \(name): \(error)")
            return []
        }
    }
    
    private func parseRSS(data: Data, source: String) -> [RawNewsItem] {
        let parser = RSSParser(data: data, source: source)
        return parser.parse()
    }
}

// Simple RSS Parser
private class RSSParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    private let source: String
    private var items: [RawNewsItem] = []
    
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDateString = ""
    
    private let dateFormatter = DateFormatter()
    
    init(data: Data, source: String) {
        self.parser = XMLParser(data: data)
        self.source = source
        super.init()
        self.parser.delegate = self
        
        // Handle standard RSS and Atom date formats
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        // Try common formats
        dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss Z" 
    }
    
    func parse() -> [RawNewsItem] {
        parser.parse()
        return items
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        if currentElement == "item" || currentElement == "entry" {
            currentTitle = ""
            currentDateString = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        switch currentElement {
        case "title":
            currentTitle += string
        case "pubDate", "published", "updated":
            currentDateString += string
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" || elementName == "entry" {
            let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let dateStr = currentDateString.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var date = Date()
            if !dateStr.isEmpty {
                // Basic attempt at parsing date
                if let parsedDate = dateFormatter.date(from: dateStr) {
                    date = parsedDate
                } else {
                    // Try Atom format
                    let atomFormatter = ISO8601DateFormatter()
                    if let parsedDate = atomFormatter.date(from: dateStr) {
                        date = parsedDate
                    }
                }
            }
            
            if !title.isEmpty {
                items.append(RawNewsItem(title: title, source: source, date: date))
            }
        }
    }
}
