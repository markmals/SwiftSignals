//import UIKit
//
//struct PodcastManager {
//    func search(for query: String) async throws -> [String] {
//        fatalError()
//    }
//}
//
//extension UISearchBar {
//    var textSignal: String {
//        fatalError()
//    }
//}
//
//class ReactiveDataSource<S: Hashable, T: Hashable>: NSObject, UICollectionViewDataSource {
//    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        fatalError()
//    }
//
//    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        fatalError()
//    }
//
//    func apply(_ apply: () -> NSDiffableDataSourceSnapshot<S, T>?) {
//        fatalError()
//    }
//}
//
//
//@MainActor
//final class ViewController: UICollectionViewController {
//    enum Section: Int { case main, one }
//
//    private let searchController = UISearchController()
//    private let manager = PodcastManager()
//    private let dataSource = ReactiveDataSource<Section, String>()
//
//    private let button = UIButton()
//    private let label = UILabel()
//
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        self.collectionView.dataSource = dataSource
//
//        // Vue-style run-once setup
//        let count = signal(1)
//        let doubleCount = memo(count.get() * 2)
//
//        button.addAction(
//            UIAction(title: "Increment", handler: { _ in count.set(count.get() + 1) }),
//            for: .touchUpInside
//        )
//
//        effect {
//            self.label.text = "Double \(count.get()) is \(doubleCount())"
//        }
//
//        let podcasts = resource {
//            try await manager.search(for: searchController.searchBar.textSignal)
//        }
//
//        dataSource.apply {
//            if let pods = podcasts.value, podcasts.status != .errored {
//                var snapshot = NSDiffableDataSourceSnapshot<Section, String>()
//                snapshot.appendSections([.one])
//                snapshot.appendItems(pods)
//                return snapshot
//            }
//
//            return nil
//        }
//    }
//}


