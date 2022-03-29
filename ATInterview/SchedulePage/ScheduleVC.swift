//
//  ScheduleVC.swift
//  ATInterview
//
//  Created by JerryLo on 2022/3/26.
//

import UIKit
import RxSwift
import SnapKit
import RxCocoa
import RxDataSources

class ScheduleVC: UIViewController {
    
    private lazy var dateBar: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 60)
        layout.sectionInset = UIEdgeInsets(top: 0, left: 30, bottom: 0, right: 30)
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: CGRect.zero,collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor.gray
        collectionView.register(DateBarCell.self, forCellWithReuseIdentifier: "DateBarCell")
        
        collectionView.rx.itemSelected
            .map { indexPath in
                return (indexPath, self.dateBarDataSource[indexPath])
            }
            .subscribe(onNext: { (indexPath, schedule) in
                self.currentIndexPath = indexPath
                self.scrollToItemCenter()
            })
            .disposed(by: disposeBag)

        return collectionView
    }()
    
    private lazy var scheduleCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.itemSize = CGSize(width: self.view.frame.width, height: self.view.frame.height - 260)
        layout.scrollDirection = .horizontal
        let collectionView = UICollectionView(frame: CGRect.zero ,collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.register(ScheduleCollectionViewCell.self, forCellWithReuseIdentifier: "ScheduleCollectionViewCell")
        collectionView.delegate = self
        collectionView.dataSource = self

        return collectionView
    }()
    
    private lazy var previousBtn: UIButton = {
        let button = UIButton(type: .custom)
        
        button.setImage(UIImage(named: "previous_arrow"), for: .normal)
        button.isEnabled = false
        
        button.rx.tap.subscribe(onNext: {
            self.arrowBtnPressed(isNext: false)
        }).disposed(by: disposeBag)

        return button
    }()
    
    private lazy var nextBtn: UIButton = {
        let button = UIButton(type: .custom)
        
        button.setImage(UIImage(named: "next_arrow"), for: .normal)

        button.rx.tap.subscribe(onNext: {
            self.arrowBtnPressed(isNext: true)
        }).disposed(by: disposeBag)

        return button
    }()
    
    private lazy var startToEndTimeLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.gray
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private lazy var timezoneHintLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private lazy var dateBarDataSource = RxCollectionViewSectionedReloadDataSource
        <SectionModel<String, UiSchedule>>(
        configureCell: { (dataSource, collectionView, indexPath, element) in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "DateBarCell", for: indexPath) as! DateBarCell
            
            cell.updateUI(schedule: element, isSelected: indexPath == self.currentIndexPath)
            
            if indexPath == self.currentIndexPath {
                cell.contentView.backgroundColor = .amazingTalkerGreen.withAlphaComponent(0.7)
            }
            else {
                cell.contentView.backgroundColor = .white
            }
            
            return cell
        }
    )

    private let disposeBag = DisposeBag()
    private let viewModel: ScheduleVM
    private var uiScheduleList: UiScheduleList?
    private var currentIndexPath = IndexPath(item: 0, section: 0)
    private var currentTimestamp = Int(Date().timeIntervalSince1970)

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        getUiScheduleList()
        dataBinding()
    }

    public init(viewModel: ScheduleVM = .init()) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        self.view.backgroundColor = .white
        view.addSubview(previousBtn)
        view.addSubview(nextBtn)
        view.addSubview(startToEndTimeLabel)
        view.addSubview(timezoneHintLabel)
        view.addSubview(dateBar)
        view.addSubview(scheduleCollectionView)
        
        previousBtn.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(50)
            make.left.equalToSuperview()
            make.height.equalTo(40)
            make.width.equalTo(60)
        }
        
        nextBtn.snp.makeConstraints { make in
            make.height.width.centerY.equalTo(previousBtn)
            make.left.equalTo(previousBtn.snp.right).offset(5)
        }
        
        startToEndTimeLabel.snp.makeConstraints { make in
            make.left.equalTo(nextBtn.snp.right).offset(5)
            make.right.equalToSuperview().offset(10)
            make.centerY.equalTo(previousBtn)
        }
        
        timezoneHintLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(10)
            make.top.equalTo(previousBtn.snp.bottom)
        }

        dateBar.snp.makeConstraints { make in
            make.top.equalTo(timezoneHintLabel.snp.bottom).offset(10)
            make.left.right.equalToSuperview()
            make.height.equalTo(100)
        }
        
        scheduleCollectionView.snp.makeConstraints { make in
            make.top.equalTo(dateBar.snp.bottom).offset(20)
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview().inset(30)
        }
        
        self.timezoneHintLabel.text = viewModel.getTimeZoneHint()
    }
    
    private func arrowBtnPressed(isNext: Bool) {
        if isNext {
            currentTimestamp += Date().weekSec
        }
        else {
            currentTimestamp -= Date().weekSec
        }
        
        updatePreviousBtn()
        getUiScheduleList()
    }
   
    private func getUiScheduleList() {
        viewModel.getScheduleViewObject(timestamp: currentTimestamp)
    }
    
    private func dataBinding() {
        viewModel.getScheduleSubject.asObserver()
            .map({ viewObject -> String in
                self.uiScheduleList = viewObject
                self.scheduleCollectionView.reloadData()
                self.dateBar.reloadData()
                return viewObject.startToEndTime
            })
            .bind(to: self.startToEndTimeLabel.rx.text)
            .disposed(by: disposeBag)
         
        viewModel.dateBarDataSubject
            .bind(to: dateBar.rx.items(dataSource: dateBarDataSource))
            .disposed(by: disposeBag)
    }
    
    private func updatePreviousBtn() {
        previousBtn.isEnabled = Double(currentTimestamp) > Date().timeIntervalSince1970
    }
    
    
}

extension ScheduleVC: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return uiScheduleList?.scheduleList.count ?? 0;
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ScheduleCollectionViewCell", for: indexPath) as! ScheduleCollectionViewCell
        
        if let scheudle = uiScheduleList?.scheduleList[indexPath.row] {
            cell.updateUI(schedule: scheudle)
        }
        
        return cell
        
    }

}

extension ScheduleVC: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView == scheduleCollectionView {
            updateCurrentIndexPath()
            scrollToItemCenter()
        }
    }
        
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView == scheduleCollectionView {
            updateCurrentIndexPath()
            scrollToItemCenter()
        }
    }

    private func updateCurrentIndexPath() {
        let rulerCenterPoint = CGPoint(x: scheduleCollectionView.center.x + scheduleCollectionView.contentOffset.x, y: self.view.frame.height/2)
        let centerCellIndexPath = scheduleCollectionView.indexPathForItem(at: rulerCenterPoint)
        
        if let indexPath = centerCellIndexPath {
            currentIndexPath = indexPath
        }
        
    }
    
    private func scrollToItemCenter() {
        self.scheduleCollectionView.scrollToItem(at: currentIndexPath, at: .centeredHorizontally, animated: true)
        dateBar.reloadData()
        self.dateBar.scrollToItem(at: currentIndexPath, at: .centeredHorizontally, animated: true)
    }
        
}

