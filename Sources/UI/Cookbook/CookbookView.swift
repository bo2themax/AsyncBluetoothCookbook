import SwiftUI

struct CookbookView: View {
        
    var body: some View {
        NavigationView {
            List {
                NavigationLink("Scaner", destination: ScanView())
                Section("Cookbook Demo") {
                    if #available(iOS 17.0, *) {
                        NavigationLink("Advertiser", destination: AdvertisingView())
                        NavigationLink("Scanner", destination: ScannerView())
                    }
                }
            }
            .navigationTitle("Cookbook\nAsyncBluetooth")
        }
    }
}

struct CookbookView_Previews: PreviewProvider {
    static var previews: some View {
        CookbookView()
            .preferredColorScheme(.dark)
    }
}
