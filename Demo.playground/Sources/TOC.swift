//
//  TOC.swift
//  TableOfContents
//
//  Created by Jannik Lorenz on 2021-05-15.
//


import UIKit
import SwiftUI


// MARK: TOCContent protocol

public protocol TOCContent {
    static func toItem(item: Self) -> (id: AnyHashable, title: String)
}



// MARK: Mail TOC struct

public struct TOC {
    private var tocItems: [Entry] = []
    
    init(@TOC.Builder _ content: () -> [TOC.Entry]) {
        self.tocItems = content()
    }
    
    func getItems(limit: Int) -> [TOC.Item] {
        let totalItems = tocItems.reduce(0) { $0 + $1.count }
        return tocItems.reduce([]) { result, toc in
            switch toc {
            case .item(let item):
                return result + [item]
            case .items(let items):
                let limit = Int(Double(items.count) / Double(totalItems) * Double(limit))
                return result + Array(items.squeeze(limit))
            }
        }
    }
    
    func overlay(proxy: ScrollViewProxy) -> some View {
        TOC.ItemSliderView(proxy: proxy, toc: self)
            .padding()
    }
}



// MARK: Abstract Entry

extension TOC {
    enum Entry {
        case item(item: TOC.Item)
        case items(items: [TOC.Item])
        
        var count: Int {
            switch self {
            case .item(_): return 1
            case .items(let items): return items.count
            }
        }
    }
}



// MARK: Item and ItemGroup

extension TOC {
    public struct Item: Hashable {
        fileprivate var uuid = UUID()
        var id: AnyHashable?
        var value: Kind
        
        init(_ kind: Kind, id: AnyHashable? = nil) {
            self.id = id
            self.value = kind
        }
        
        enum Kind: Hashable {
            case letter(_ string: String)
            case symbol(_ name: String)
            case placeholder
        }
        
        var toView: AnyView {
            switch value {
            case .letter(let string):
                return AnyView(Text(string))
            case .symbol(let name):
                return AnyView(Image(systemName: name))
            case .placeholder:
                return AnyView(Text(""))
            }
        }
    }
}

extension TOC {
    public struct ItemGroup {
        var items: [TOC.Item]
        
        init(items: [TOC.Item]) {
            self.items = items
        }
        
        static let alphabet = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
        init<T>(data: [T], convert: (T) -> (id: AnyHashable, title: String) ) {
            let tocCandidates = data.map(convert)
            self.items = Self.alphabet.compactMap { letter in
                tocCandidates.first { $0.title.uppercased().hasPrefix(letter) }
            }.map { TOC.Item(.letter(String($0.title.uppercased().prefix(1))), id: $0.id)}
        }
    }
}



// MARK: TOC View

extension TOC {
    fileprivate struct ItemSliderView: View {
        let proxy: ScrollViewProxy
        let toc: TOC
        @GestureState private var dragLocation: CGPoint = .zero
        @State var isHover = false
        @State var selectedItem: TOC.Item?
        
        var body: some View {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    VStack {
                        ForEach(toc.getItems(limit: Int(geometry.size.height*0.80 / 20.0)), id: \.uuid) { item in
                            item.toView
                                .opacity(isHover ? (item == selectedItem ? 1.0 : 0.75) : 0.5)
                                .frame(width: 40, height: 20)
                                .contentShape(Rectangle())
                                .background(dragObserver(item: item))
                        }
                        .frame(width: 20)
                    }
                    .padding(4)
                    .padding(.trailing, 6)
                    .background(Color(UIColor.secondarySystemGroupedBackground).opacity(0.5))
                    .cornerRadius(12)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .updating($dragLocation) { value, state, _ in state = value.location }
                            .onChanged({ _ in isHover = true })
                            .onEnded({ _ in isHover = false })
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    Spacer()
                }
            }
        }

        func dragObserver(item: TOC.Item) -> some View {
            GeometryReader { geometry in
                dragObserver(geometry: geometry, item: item)
            }
        }

        func dragObserver(geometry: GeometryProxy, item: TOC.Item) -> some View {
            if geometry.frame(in: .global).contains(dragLocation) {
                DispatchQueue.main.async {
                    selectedItem = item
                    proxy.scrollTo(item.id, anchor: .top)
                }
            }
            return Rectangle().fill(Color.clear)
        }
    }
}



// MARK: TOC Builder

extension TOC {
    @resultBuilder
    struct Builder {
        static func buildBlock() -> [TOC.Entry] { [] }
        
        static func buildBlock(_ values: TOCEntryConvertible...) -> [TOC.Entry] {
            values.flatMap { $0.asEntry() }
        }

        static func buildIf(_ value: TOCEntryConvertible?) -> TOCEntryConvertible {
            value ?? []
        }

        static func buildEither(first: TOCEntryConvertible) -> TOCEntryConvertible {
            first
        }

        static func buildEither(second: TOCEntryConvertible) -> TOCEntryConvertible {
            second
        }
    }
}

protocol TOCEntryConvertible {
    func asEntry() -> [TOC.Entry]
}

extension TOC.Item: TOCEntryConvertible {
    func asEntry() -> [TOC.Entry] { [TOC.Entry.item(item: self)] }
}

extension TOC.ItemGroup: TOCEntryConvertible {
    func asEntry() -> [TOC.Entry] {
        [TOC.Entry.items(items: self.items)]
    }
}

extension TOC.Item.Kind: TOCEntryConvertible {
    func asEntry() -> [TOC.Entry] {
        TOC.Item(self).asEntry()
    }
}

extension Array: TOCEntryConvertible where Element == TOC.Entry {
    func asEntry() -> [TOC.Entry] { self }
}



// MARK: Array squeeze helper

extension Array where Element == TOC.Item {
    func squeeze(_ totalItemsFittable: Int) -> [TOC.Item] {
        if totalItemsFittable > self.count - 2 {
            return self
        }
        
        // Only accept odd numbers of items to get the correct amount of • placeholders
        let isOddNumber = totalItemsFittable % 2 == 1
        var totalItemsToShow = isOddNumber ? totalItemsFittable : totalItemsFittable - 1
        
        // Subtract two so we can fit the first and last items the user provided
        totalItemsToShow -= 2
        
        // Since it's an odd number, this will integer round down so that there is 1 less index shown than placeholders
        let totalUserItemsToShow = totalItemsToShow // / 2
        
        let showEveryNthCharacter = CGFloat(self.count-2) / CGFloat(totalUserItemsToShow)
        
        var userItemsToShow: [TOC.Item] = []
        
        // Drop the first and last index because we have them covered by the user-provided items
        for i in stride(from: CGFloat(1), to: CGFloat(self.count-1), by: showEveryNthCharacter) {
            if i == 0 {
                continue
            }
            userItemsToShow.append(self[Int(i.rounded())])
            
            if userItemsToShow.count == totalUserItemsToShow {
                // Since we're incrementing by fractional numbers ensure we don't grab one too many and go beyond our indexes
                break
            }
        }
        
        var itemsToShow: [TOC.Item] = []
        if let first = self.first {
            itemsToShow.append(first)
        }
        
        // Every second one show a placeholder
        for item in userItemsToShow {
            itemsToShow.append(item)
        }
        
        if let last = self.last {
            itemsToShow.append(last)
        }
        
        return itemsToShow
    }
}

