//
//  CLAUDE.md
//  DD-iOS
//
//  Created by Sarvesh Shanmugam on 4/8/26.
//
## Project Overview
                
DamageDoctor iOS app — camera-based car damage detection using two CoreML models in a pipeline:
                
1. **DamageClassifier.mlpackage** (~4MB) — MobileNetV3-Small binary classifier
   - Input: 224x224 RGB image
   - Output: single logit. Apply sigmoid: < 0.5 → damage, >= 0.5 → no_damage
   - Purpose: fast gate to avoid running the heavier detector on clean cars
                                                                                                                                 
2. **DamageDetector.mlpackage** (~22MB) — YOLOv8s object detector
   - Input: 640x640 RGB image
   - Output: bounding boxes with class labels and confidence scores
   - 6 classes: dent, scratch, crack, glass shatter, lamp broken, tire flat
   - Only run when the classifier detects damage
 
## App Flow
                
1. User takes or selects a photo of their car
2. Run DamageClassifier — if no_damage, show "No damage detected"
3. If damage, run DamageDetector — draw bounding boxes on the image
4. Display results: damage type labels, confidence scores, annotated image
5. User can save/share the annotated result
                                                                                                                                 
## Technical Notes
                
- Minimum target: iOS 15
- Swift + SwiftUI
- Use Vision framework for CoreML inference
- Classifier uses ImageNet normalization (mean=[0.485,0.456,0.406], std=[0.229,0.224,0.225])
- Detector NMS is baked into the CoreML model
- Both models run well on-device (classifier ~5ms, detector ~20ms on recent iPhones)
                                                                                                                                 
## Beta Scope
                                                                                                                                 
This is a beta/MVP. Keep it simple:
- Single photo capture or pick from library
- Results screen with annotated image
- No accounts, no backend, no history — just on-device inference
