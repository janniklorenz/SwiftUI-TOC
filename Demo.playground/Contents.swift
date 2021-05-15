import SwiftUI
import PlaygroundSupport

struct MyData: Identifiable {
    var id = UUID()
    var title: String
}

//extension MyData: TOCContent {
//    static func toItem(item: Self) -> (id: AnyHashable, title: String) {
//        return (item.id, item.title)
//    }
//}

let data = [
    MyData(title: "Alpha"),
    MyData(title: "Beta"),
    MyData(title: "Delta"),
    MyData(title: "Test"),
    MyData(title: "Demo"),
    MyData(title: "Outside"),
    MyData(title: "Inside"),
    MyData(title: "Device"),
    MyData(title: "Phone")
]


struct ContentView: View {
    var body: some View {
        ForEach(data) { item in
            Text(item.title)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

PlaygroundPage.current.setLiveView(ContentView())
