//
//  ViewController.swift
//  DetectSomeAnimals
//
//  Created by baonv on 12/14/20.
//  Copyright © 2020 baonv. All rights reserved.
//

import UIKit
import CoreML
import Vision
import ImageIO

final class ImageClassificationViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var classificationLabel: UILabel!
    @IBOutlet weak var cameraButton: UILabel!
    @IBOutlet weak var visualView: UIVisualEffectView!
    var resultAnimal: String = "Dog"
    
    lazy private var infoClassificationRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: AnimalsImageClassifier_1().model)
            
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            }
            request.imageCropAndScaleOption = .centerCrop
            return request
            
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    lazy private var detectClassification: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: DetectImageClassifier_2().model)
            
            let request = VNCoreMLRequest(model: model) { [weak self] request, error in
                self?.detectClassifications(for: request, error: error)
            }
            request.imageCropAndScaleOption = .centerCrop
            return request
            
        } catch {
            fatalError("Failed to load Vision ML model: \(error)")
        }
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        visualView.layer.masksToBounds = true
        visualView.layer.cornerRadius = 8
    }
    
    private func updateClassifications(for image: UIImage) {
        classificationLabel.text = "Classifying..."
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        guard let ciImage = CIImage(image: image) else {
            fatalError("Unable to create \(CIImage.self) from \(image).")
        }

        DispatchQueue.global(qos: .default).async {
            let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
            do {
                try handler.perform([self.infoClassificationRequest])
                try handler.perform([self.detectClassification])
            } catch {
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
    
    private func detectClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                self.classificationLabel.text = "Unable to classify image.\n\(error!.localizedDescription)"
                return
            }

            let classifications = results as! [VNClassificationObservation]
        
            if classifications.isEmpty {
                self.classificationLabel.text = "Nothing recognized."
            } else {
                let topClassifications = classifications.prefix(6)
                self.classificationLabel.text! += "\nResult: \(self.resultAnimal)"
                
                topClassifications.forEach { value in
                    if value.identifier == "Animals" {
                        if value.confidence >= 0.99 {
                            self.classificationLabel.text = "Model cannot \ndetect animal \nin this image"
                            return
                        }
                    }
                }
                
                print(self.classificationLabel.text!)
            }
        }
    }
    
    private func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results else {
                self.classificationLabel.text = "Unable to classify image.\n\(error!.localizedDescription)"
                return
            }

            let classifications = results as! [VNClassificationObservation]
        
            if classifications.isEmpty {
                self.classificationLabel.text = "Nothing recognized."
            } else {
                let topClassifications = classifications.prefix(6)
                var valueMax: Float = 0, animal: String = ""
                let descriptions: [String] = topClassifications.map { classification in
                    if valueMax < classification.confidence {
                        animal = classification.identifier
                        valueMax = classification.confidence
                    }
                    return String(format: " %@: %.0f %%", classification.identifier ,classification.confidence * 100)
                }
                self.classificationLabel.text = "Info:\n" + descriptions.joined(separator: "\n")
                self.resultAnimal = animal
            }
        }
    }
    
    @IBAction func takePicture(_ sender: Any) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentPhotoPicker(sourceType: .photoLibrary)
            return
        }
        
        let photoSourcePicker = UIAlertController()
        let takePhoto = UIAlertAction(title: "Take Photo", style: .default) { [unowned self] _ in
            self.presentPhotoPicker(sourceType: .camera)
        }
        let choosePhoto = UIAlertAction(title: "Choose Photo", style: .default) { [unowned self] _ in
            self.presentPhotoPicker(sourceType: .photoLibrary)
        }
        
        photoSourcePicker.addAction(takePhoto)
        photoSourcePicker.addAction(choosePhoto)
        photoSourcePicker.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(photoSourcePicker, animated: true)
    }
    
    private func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }
}

extension ImageClassificationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        let image = info[UIImagePickerController.InfoKey(rawValue: UIImagePickerController.InfoKey.originalImage.rawValue)] as! UIImage
        imageView.image = image
        //imageView.contentMode = .scaleAspectFill
        updateClassifications(for: image)
    }
    
}

