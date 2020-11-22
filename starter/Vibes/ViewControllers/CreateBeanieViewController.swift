import UIKit
import CoreML
import Vision


class CreateBeanieViewController: UIViewController {
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var beanieTextView: UITextView!
  @IBOutlet weak var addStickerButton: UIBarButtonItem!
  @IBOutlet weak var stickerView: UIView!
	@IBOutlet weak var starterLabel: UILabel!
	
  private lazy var classificationRequest: VNCoreMLRequest = {
    do {
      let model = try VNCoreMLModel(for: BeanieNotBeanie().model)
      let request = VNCoreMLRequest(model: model) { [weak self] request, error in
          guard let self = self else {
            return
        }
        self.processClassifications(for: request, error: error)
      }

      request.imageCropAndScaleOption = .centerCrop
      return request
    } catch {
      fatalError("Failed to load Vision ML model: \(error)")
    }
  }()
  
  private lazy var stickerFrame: CGRect = {
    let stickerHeightWidth = 50.0
    let stickerOffsetX =
      Double(stickerView.bounds.midX) - (stickerHeightWidth / 2.0)
    let stickerRect = CGRect(
      x: stickerOffsetX,
      y: 80.0, width:
      stickerHeightWidth,
      height: stickerHeightWidth)
    return stickerRect
  }()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    beanieTextView.isHidden = true
  }
  
  @IBAction func selectPhotoPressed(_ sender: Any) {
    let picker = UIImagePickerController()
    picker.delegate = self
    picker.sourceType = .photoLibrary
    picker.modalPresentationStyle = .overFullScreen
    present(picker, animated: true)
  }
  
  @IBAction func cancelPressed(_ sender: Any) {
    dismiss(animated: true)
  }
}

private extension CreateBeanieViewController {
  
  func getIt(for keywords: [String]? = nil) -> String? {
    if (keywords?[0] == "n02107312-miniature_pinscher")
    {
      return "Not Beanie"
    }
    if (keywords?[0] == "beanie-dataset")
    {
    return "Beanie"
    }

    return "Not Beanie"
  }
  
  func processClassifications(for request: VNRequest, error: Error?) {
    DispatchQueue.main.async {
      // 1
      if let classifications =
        request.results as? [VNClassificationObservation] {
        // 2
        let topClassifications = classifications.prefix(1).map {
          (confidence: $0.confidence, identifier: $0.identifier)
        }
        print("Top classifications: \(topClassifications)")
        let topIdentifiers =
          topClassifications.map {$0.identifier.lowercased() }
        // 3
        if let it = self.getIt(for: topIdentifiers) {
          self.beanieTextView.text = it
        }
      }
    }
  }

}

extension CreateBeanieViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    picker.dismiss(animated: true)
    
    let image = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
    imageView.image = image
    beanieTextView.isHidden = false
		starterLabel.isHidden = true
    classifyImage(image)
  }
  
  func classifyImage(_ image: UIImage) {
    guard let orientation = CGImagePropertyOrientation(
      rawValue: UInt32(image.imageOrientation.rawValue)) else {
      return
    }
    guard let ciImage = CIImage(image: image) else {
      fatalError("Unable to create \(CIImage.self) from \(image).")
    }
    DispatchQueue.global(qos: .userInitiated).async {
      let handler =
        VNImageRequestHandler(ciImage: ciImage, orientation: orientation)
      do {
        try handler.perform([self.classificationRequest])
      } catch {
        print("Failed to perform classification.\n\(error.localizedDescription)")
      }
    }
  }

}

extension CreateBeanieViewController: UIGestureRecognizerDelegate {
  @objc func handlePanGesture(_ recognizer: UIPanGestureRecognizer) {
    let translation = recognizer.translation(in: stickerView)
    if let view = recognizer.view {
      view.center = CGPoint(
        x:view.center.x + translation.x,
        y:view.center.y + translation.y)
    }
    recognizer.setTranslation(CGPoint.zero, in: stickerView)
    
    if recognizer.state == UIGestureRecognizer.State.ended {
        let velocity = recognizer.velocity(in: stickerView)
        let magnitude =
          sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))
        let slideMultiplier = magnitude / 200
          
        let slideFactor = 0.1 * slideMultiplier
        var finalPoint = CGPoint(
          x:recognizer.view!.center.x + (velocity.x * slideFactor),
          y:recognizer.view!.center.y + (velocity.y * slideFactor))
        finalPoint.x =
          min(max(finalPoint.x, 0), stickerView.bounds.size.width)
        finalPoint.y =
          min(max(finalPoint.y, 0), stickerView.bounds.size.height)
          
        UIView.animate(
          withDuration: Double(slideFactor * 2),
          delay: 0,
          options: UIView.AnimationOptions.curveEaseOut,
          animations: {recognizer.view!.center = finalPoint },
          completion: nil)
    }
  }
}
