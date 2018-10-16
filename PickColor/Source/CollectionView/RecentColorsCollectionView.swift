import UIKit
import CoreData

public protocol RecentColorsCollectionViewDelegate: class {
    func didSelectRecent(color: UIColor)
}

public class RecentColorsCollectionView: UICollectionView,
    UICollectionViewDelegate,
    UICollectionViewDataSource,
    RecentColorCollectionViewCellDelegate,
    NSFetchedResultsControllerDelegate {

    //  MARK: - Public properties

    public weak var recentColorDelegate: RecentColorsCollectionViewDelegate?

    //  MARK: - Private properties

    private var size: CGSize = .zero {
        didSet {
            if oldValue != size {
                didChangeSize()
            }
        }
    }

    private let flowLayout = UICollectionViewFlowLayout()

    private var boundsObserver: NSKeyValueObservation!

    private var blockOperations = [BlockOperation]()

    private lazy var fetchedResultController: NSFetchedResultsController<Color> = {
        let fr = NSFetchRequest<Color>(entityName: Color.self.description())
        fr.sortDescriptors = [NSSortDescriptor(keyPath: \Color.lastUsed, ascending: false)]
        let frc = NSFetchedResultsController(fetchRequest: fr,
                                             managedObjectContext: Persistance.container.viewContext,
                                             sectionNameKeyPath: nil,
                                             cacheName: nil)
        frc.delegate = self
        return frc

    }()

    init() {
        super.init(frame: .zero, collectionViewLayout: flowLayout)

        delegate = self
        dataSource = self
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        backgroundColor = .clear

        flowLayout.scrollDirection = .vertical

        register(RecentColorCollectionViewCell.self, forCellWithReuseIdentifier: RecentColorCollectionViewCell.identifier)

        reloadData()
        layoutIfNeeded()

        boundsObserver = observe(\.bounds, changeHandler: { (observing, change) in
            self.size = self.bounds.size
        })

        do {
            try fetchedResultController.performFetch()
        } catch {
            fatalError(error.localizedDescription)
        }

        reloadData()
    }

    func didChangeSize() {
        // flowLayout.itemSize = CGSize(width: frame.height, height: frame.height)
        flowLayout.itemSize = CGSize(width: 44, height: 44)
        flowLayout.invalidateLayout()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func numberOfSections(in collectionView: UICollectionView) -> Int {
        return fetchedResultController.sections!.count
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let sections = fetchedResultController.sections else { return 0 }
        return sections[0].numberOfObjects
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: RecentColorCollectionViewCell.identifier, for: indexPath) as! RecentColorCollectionViewCell
        cell.color = fetchedResultController.object(at: indexPath).uiColor
        cell.delegate = self
        return cell
    }

    // MARK: - RecentColorCollectionViewCellDelegate
    public func didSelectRecent(color: UIColor) {
        recentColorDelegate?.didSelectRecent(color: color)
    }

    // MARK: - NSFetchedResultsControllerDelegate

    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            blockOperations.append(BlockOperation {
                self.insertItems(at: [newIndexPath!])
            })
        case .update:
            blockOperations.append(BlockOperation {
                self.reloadItems(at: [indexPath!])
            })
        case .delete:
            blockOperations.append(BlockOperation {
                self.deleteItems(at: [indexPath!])
            })
        case .move:
            blockOperations.append(BlockOperation {
                self.moveItem(at: indexPath!, to: newIndexPath!)
            })
        }
    }

    public func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        blockOperations = []
    }

    public func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        performBatchUpdates({ blockOperations.forEach { $0.start() } }, completion: nil)
    }

}
