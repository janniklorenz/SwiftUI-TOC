# SwiftUI Components for a custom Table Of Contents

## How to Use

`````swift
ScrollViewReader { proxy in
    List {
        ForEach(1..<20) { i in
            Text("\(i)").id(i)
        }
    }
    .overlay(TOC{
        TOC.Item(.letter("1"), id: 1)
        TOC.Item(.letter("10"), id: 10)
    }.overlay(proxy: proxy))
}
````
