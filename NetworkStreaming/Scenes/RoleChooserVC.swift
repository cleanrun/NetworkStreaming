//
//  RoleChooserVC.swift
//  NetworkStreaming
//
//  Created by cleanmac on 23/11/23.
//

import UIKit

final class RoleChooserVC: UIViewController {
    
    private var buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    private lazy var hostButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Host", for: .normal)
        button.setTitleColor(.link, for: .normal)
        button.addTarget(self, action: #selector(hostAction), for: .touchUpInside)
        return button
    }()
    
    private lazy var streamerButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Streamer", for: .normal)
        button.setTitleColor(.link, for: .normal)
        button.addTarget(self, action: #selector(streamerAction), for: .touchUpInside)
        return button
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        
        view.backgroundColor = .systemBackground
        
        view.addSubview(buttonStackView)
        buttonStackView.addArrangedSubview(hostButton)
        buttonStackView.addArrangedSubview(streamerButton)
        
        NSLayoutConstraint.activate([
            buttonStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            buttonStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    @objc private func hostAction() {
        navigationController?.pushViewController(HostVC(), animated: true)
    }
    
    @objc private func streamerAction() {
        navigationController?.pushViewController(StreamerVC(), animated: true)
    }
    
}
