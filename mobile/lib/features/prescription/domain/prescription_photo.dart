/// How a prescription photo is shrunk on the phone before upload (passed to
/// ImagePicker.pickImage). A full camera photo is often 3-8 MB; at 2000 px on
/// the long side and quality 80 it is a few hundred KB and handwriting stays
/// readable for the pharmacist. Smaller photos are left at their size.
const double prescriptionPhotoMaxSide = 2000;
const int prescriptionPhotoQuality = 80;
