from roboflow import Roboflow
import cv2

# Initialize Roboflow model once
rf = Roboflow(api_key="x")
project = rf.workspace().project("student_detection-f0x91")
model = project.version(4).model

def detect_from_image():
    path = input("Enter image path: ")
    img = cv2.imread(path)
    if img is None:
        print("❌ Image not found! Please check the path.")
        return

    results = model.predict(img, confidence=40).json()
    count = len(results["predictions"])
    print(f"Number of people detected: {count}")

    for pred in results["predictions"]:
        x, y, w, h = int(pred["x"]), int(pred["y"]), int(pred["width"]), int(pred["height"])
        cv2.rectangle(img, (x - w // 2, y - h // 2),
                      (x + w // 2, y + h // 2), (0, 255, 0), 2)
        cv2.putText(img, pred["class"], (x - w // 2, y - h // 2 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

    cv2.imshow("Detection", img)
    cv2.waitKey(0)
    cv2.destroyAllWindows()


def detect_from_camera():
    cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
    print("Press 'q' to stop detection and return to menu.\n")

    while True:
        ret, frame = cap.read()
        if not ret:
            print("❌ Failed to grab frame")
            break

        results = model.predict(frame, confidence=40).json()
        person_count = len(results["predictions"])
        print("People detected:", person_count)

        for pred in results["predictions"]:
            x, y, w, h = int(pred["x"]), int(pred["y"]), int(pred["width"]), int(pred["height"])
            cv2.rectangle(frame, (x - w // 2, y - h // 2),
                          (x + w // 2, y + h // 2), (0, 255, 0), 2)
            cv2.putText(frame, pred["class"], (x - w // 2, y - h // 2 - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

        cv2.imshow("AI Detection", frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            print("🛑 Detection stopped. Returning to menu...")
            break

    cap.release()
    cv2.destroyAllWindows()


def check_lab(video_source):
    cap = cv2.VideoCapture(video_source)
    ret, frame = cap.read()
    if not ret:
        print("Error reading video.")
        return None

    results = model.predict(frame, confidence=40).json()
    people = len(results["predictions"])

    if people > 0:
        print("Lab Status: OCCUPIED (People Detected:", people, ")")
        status = "Occupied"
    else:
        print("Lab Status: FREE (No people detected)")
        status = "Free"

    cap.release()
    return status


# 🔁 Main Loop
while True:
    print("\n--- LAB OCCUPANCY MONITOR ---")
    print("1. Detect people from an image")
    print("2. Detect people from the live camera")
    print("3. Check if the lab is occupied or not")
    print("4. Exit")

    choice = input("Enter your choice: ")

    if choice == "1":
        detect_from_image()

    elif choice == "2":
        detect_from_camera()

    elif choice == "3":
        status = check_lab(0)  # Webcam (or replace with video path)
        print("Final Output:", status)

    elif choice == "4":
        print("✅ Program terminated. Bye bro 👋")
        break

    else:

        print("❌ Invalid choice! Try again.")
