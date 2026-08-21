# คำถามที่พบบ่อย (ภาษาไทย)

<details>
<summary><b>ทำไมไฟล์ image ถึงไม่อยู่ใน repo?</b></summary><br>
GitHub จำกัดไฟล์ที่ push ได้ไม่เกิน 100 MB ส่วน Git LFS จำกัด 2 GB ต่อไฟล์ แต่ image นี้ขนาด 10.25 GiB จึงต้องแบ่งเป็นส่วนย่อยแล้วอัปโหลดเป็น GitHub Release assets (จำกัด 2 GB ต่อไฟล์ แต่ไม่จำกัดจำนวน) ใช้ <code>scripts/download-image.sh</code> ดาวน์โหลดและต่อกลับให้อัตโนมัติ
</details>

<details>
<summary><b>ใช้ SD card 32 GB ได้ไหม?</b></summary><br>
ได้ แต่พอดีเป๊ะมาก — image ขนาด 29.00 GiB ส่วนการ์ด 32 GB จริง ๆ มีประมาณ 29.7 GiB แนะนำ 64 GB UHS-I U3 จะสบายกว่ามาก เพราะ rootfs จะขยายเต็มการ์ดตอนบูตครั้งแรก
</details>

<details>
<summary><b>ใช้กับ Orin Nano / Xavier NX ได้ไหม?</b></summary><br>
ไม่ได้ครับ image นี้เป็น L4T R32.7.6 สำหรับ Tegra X1 (Jetson Nano) เท่านั้น Orin ต้องใช้ JetPack 5/6 ซึ่ง boot chain คนละแบบ
</details>

<details>
<summary><b>ใช้กับ Jetson Nano รุ่น eMMC (P3448-0002) ได้ไหม?</b></summary><br>
ไม่ได้ image นี้สำหรับรุ่น microSD (P3448-0000, 4 GB) เท่านั้น รุ่น eMMC ต้อง flash ผ่าน USB recovery mode ด้วย L4T BSP
</details>

<details>
<summary><b>บูตแล้วจอดำ ทำยังไง?</b></summary><br>
เช็คตามลำดับ: (1) เสียบการ์ดแล้วดูใน host ว่ามี 14 partitions ไหม ถ้าไม่มีแปลว่า flash ไม่สำเร็จ (2) ลองการ์ดใบอื่น (3) เช็คว่าเป็น Nano รุ่น microSD (4) ใช้ไฟ barrel jack 5V 4A พร้อมใส่ jumper J48 — ปัญหาส่วนใหญ่คือไฟไม่พอ ดูรายละเอียดที่ <a href="TROUBLESHOOTING.md">TROUBLESHOOTING.md</a>
</details>

<details>
<summary><b><code>torch.cuda.is_available()</code> ได้ False</b></summary><br>
แปลว่ามีอะไรไปทับ PyTorch ตัวที่ NVIDIA build ไว้ (ปกติเกิดจากการรัน <code>pip install torch</code> หรือ <code>pip install -r requirements.txt</code>) วิธีที่เร็วที่สุดคือ flash ใหม่ ซึ่งคือเหตุผลที่ golden image มีอยู่
</details>

<details>
<summary><b>ทำไม FPS ต่ำ?</b></summary><br>
เรียงตามผลกระทบ: (1) <code>sudo nvpmodel -m 0 && sudo jetson_clocks</code> (2) ใช้ TensorRT engine แทน PyTorch (3) ลด <code>--img</code> เป็น 416 (4) เช็คความร้อนด้วย <code>sudo jtop</code> — ถ้าไม่มีพัดลม จะ throttle เร็วมาก
</details>

<details>
<summary><b>เทรนโมเดลบน Nano ได้ไหม?</b></summary><br>
ในทางปฏิบัติไม่ควรครับ RAM 4 GB แชร์ระหว่าง CPU/GPU และมี 128 CUDA cores เหมาะกับ inference เท่านั้น ควรเทรนบนเครื่อง desktop หรือ Colab แล้ว export เป็น ONNX มาสร้าง TensorRT engine บน Nano
</details>

<details>
<summary><b>ต้องเปลี่ยนรหัสผ่านไหม?</b></summary><br>
ต้องครับ ทุกเครื่องที่ flash จาก image เดียวกันจะมีรหัสผ่านเหมือนกันหมด รัน <code>passwd</code> ก่อนต่อเน็ตเสมอ
</details>
