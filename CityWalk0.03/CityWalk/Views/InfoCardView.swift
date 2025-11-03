import UIKit

class InfoCardView: UIView {
    private let titleLabel = UILabel()
    private let addressLabel = UILabel()
    private let distanceLabel = UILabel()
    private let routeButton = UIButton(type: .system)
    var onRoute: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textColor = .black
        addressLabel.font = UIFont.systemFont(ofSize: 14)
        addressLabel.textColor = .darkGray
        addressLabel.numberOfLines = 2
        distanceLabel.font = UIFont.systemFont(ofSize: 13)
        distanceLabel.textColor = .gray
        distanceLabel.numberOfLines = 1
        
        routeButton.setTitle("路线/导航", for: .normal)
        routeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        routeButton.backgroundColor = UIColor.systemBlue
        routeButton.setTitleColor(.white, for: .normal)
        routeButton.layer.cornerRadius = 8
        routeButton.addTarget(self, action: #selector(routeTapped), for: .touchUpInside)
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, distanceLabel, addressLabel, routeButton])
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .leading
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            routeButton.heightAnchor.constraint(equalToConstant: 40),
            routeButton.widthAnchor.constraint(equalToConstant: 120)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(title: String, address: String, distance: String? = nil) {
        titleLabel.text = title
        addressLabel.text = address
        distanceLabel.text = distance
        distanceLabel.isHidden = (distance == nil)
    }
    
    @objc private func routeTapped() {
        onRoute?()
    }
}
