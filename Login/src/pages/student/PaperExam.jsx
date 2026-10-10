import { useEffect, useRef, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { myExamsApi } from "../../services/api";
import { Alert, Badge, Button, PageHeader, fmtDateTime } from "../../components/ui";
import { imagesToPdf } from "../../utils/imagesToPdf";

const MAX_FILES = 15;
const MAX_MB = 10;
const isImg = (name) => /\.(png|jpe?g|gif|webp|heic)$/i.test(name || "");

/*
| Student side of a paper exam.
|   1. download the question paper
|   2. write the exam on paper
|   3. photograph / scan every page and upload them here (images or PDF)
|   4. later: marks + remarks appear here once the teacher publishes them
*/
function PaperExam() {
    const { id } = useParams();
    const [exam, setExam] = useState(null);
    const [attempt, setAttempt] = useState(null);
    const [picked, setPicked] = useState([]); // [{ file, preview }]
    const [loading, setLoading] = useState(true);
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState("");
    const [ok, setOk] = useState("");
    const previews = useRef([]);
    const [camOpen, setCamOpen] = useState(false);
    const [camError, setCamError] = useState("");
    const videoRef = useRef(null);
    const streamRef = useRef(null);

    const load = () =>
        myExamsApi.get(id).then((d) => { setExam(d.exam); setAttempt(d.attempt); }).catch((e) => setError(e.message)).finally(() => setLoading(false));

    useEffect(() => {
        load();
        const urls = previews.current;
        return () => urls.forEach((u) => URL.revokeObjectURL(u));
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [id]);

    const addFiles = (e) => {
        const list = Array.from(e.target.files || []);
        e.target.value = "";
        setError("");
        const next = [...picked];
        for (const f of list) {
            if (!(f.type.startsWith("image/") || f.type === "application/pdf")) { setError(`${f.name}: only images or PDF are allowed`); continue; }
            if (f.size > MAX_MB * 1024 * 1024) { setError(`${f.name} is larger than ${MAX_MB} MB`); continue; }
            if (next.length >= MAX_FILES) { setError(`You can upload at most ${MAX_FILES} pages`); break; }
            const preview = f.type.startsWith("image/") ? URL.createObjectURL(f) : null;
            if (preview) previews.current.push(preview);
            next.push({ file: f, preview });
        }
        setPicked(next);
    };

    const stopCamera = () => {
        streamRef.current?.getTracks().forEach((t) => t.stop());
        streamRef.current = null;
    };
    useEffect(() => stopCamera, []);

    const openCamera = async () => {
        setCamError(""); setError("");
        if (!navigator.mediaDevices?.getUserMedia) {
            setCamError("Camera needs https:// or localhost. Open the site on localhost, or use \"Choose photos\".");
            return;
        }
        try {
            let stream;
            try {
                stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment" }, audio: false });
            } catch (e) {
                if (e.name === "NotAllowedError" || e.name === "SecurityError") throw e;
                stream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false }); // plain webcam
            }
            streamRef.current = stream;
            setCamOpen(true);
            setTimeout(() => { if (videoRef.current) videoRef.current.srcObject = stream; }, 0);
        } catch (e) {
            const reasons = {
                NotAllowedError: "Camera permission is blocked. Click the lock icon in the address bar, set Camera to Allow, then refresh.",
                NotFoundError: "No camera was found on this device. Use \"Choose photos\" instead.",
                NotReadableError: "The camera is being used by another app. Close it and try again.",
                SecurityError: "The browser blocked the camera on this address. Use localhost or https.",
            };
            setCamError(reasons[e.name] || `Could not open the camera (${e.name}). Use "Choose photos" instead.`);
        }
    };

    const closeCamera = () => { stopCamera(); setCamOpen(false); };

    const snap = () => {
        const v = videoRef.current;
        if (!v || !v.videoWidth) return;
        if (picked.length >= MAX_FILES) { setError(`You can upload at most ${MAX_FILES} pages`); return; }
        const c = document.createElement("canvas");
        c.width = v.videoWidth; c.height = v.videoHeight;
        c.getContext("2d").drawImage(v, 0, 0);
        c.toBlob((blob) => {
            if (!blob) return;
            const file = new File([blob], `photo-${Date.now()}.jpg`, { type: "image/jpeg" });
            const preview = URL.createObjectURL(file);
            previews.current.push(preview);
            setPicked((p) => [...p, { file, preview }]);
        }, "image/jpeg", 0.92);
    };

    const removeAt = (i) => {
        const p = picked[i];
        if (p.preview) URL.revokeObjectURL(p.preview);
        setPicked(picked.filter((_, j) => j !== i));
    };

    const move = (i, d) => {
        const j = i + d;
        if (j < 0 || j >= picked.length) return;
        const next = [...picked];
        [next[i], next[j]] = [next[j], next[i]];
        setPicked(next);
    };

    const submit = async () => {
        if (picked.length === 0) { setError("Add at least one page"); return; }
        const photos = picked.filter((p) => p.file.type.startsWith("image/"));
        const pdfs = picked.filter((p) => p.file.type === "application/pdf");
        const msg = photos.length
            ? `Convert ${photos.length} photo(s) to a PDF and send it to your teacher?`
            : `Send ${pdfs.length} PDF file(s) to your teacher?`;
        if (!confirm(`${msg}${attempt ? " This replaces your earlier upload." : ""}`)) return;
        setBusy(true); setError(""); setOk("");
        try {
            const fd = new FormData();
            pdfs.forEach((p) => fd.append("files[]", p.file));
            if (photos.length) {
                const blob = await imagesToPdf(photos.map((p) => p.file));
                fd.append("files[]", new File([blob], "answer-sheets.pdf", { type: "application/pdf" }));
            }
            await myExamsApi.submitPaper(id, fd);
            setOk("Sent to your teacher as a PDF. You will see your marks here once they are published.");
            picked.forEach((p) => p.preview && URL.revokeObjectURL(p.preview));
            setPicked([]);
            await load();
        } catch (e) {
            setError(e.message);
        } finally {
            setBusy(false);
        }
    };

    if (loading) return <p>Loading...</p>;
    if (!exam) return <div><PageHeader title="Exam" /><Alert>{error}</Alert></div>;

    const status = attempt?.status || "pending";
    const locked = status === "graded" || status === "published";
    const canUpload = !locked && exam.is_open;

    return (
        <div className="max-w-3xl">
            <PageHeader title={exam.title} action={<Link to="/my-exams" className="text-blue-700 hover:underline">← My exams</Link>} />
            <Alert>{error}</Alert>
            <Alert type="success">{ok}</Alert>

            <div className="bg-white rounded-xl shadow p-5 mb-5">
                <div className="flex gap-2 mb-2"><Badge>paper</Badge><Badge>{status === "graded" ? "submitted" : status}</Badge></div>
                <p className="text-sm text-gray-600">{exam.subject || "—"} · {exam.total_marks} marks{exam.end_at ? ` · due ${fmtDateTime(exam.end_at)}` : ""}</p>
                {exam.instructions && <p className="whitespace-pre-line text-sm text-gray-600 bg-gray-50 rounded-lg p-3 mt-3">{exam.instructions}</p>}
            </div>

            {status === "published" && (
                <div className="bg-white rounded-xl shadow p-6 text-center mb-5">
                    <p className="text-gray-500">Your marks</p>
                    <p className="text-5xl font-bold text-blue-900 my-2">{attempt.marks} <span className="text-2xl text-gray-400">/ {exam.total_marks}</span></p>
                    {exam.pass_marks != null && (
                        <p className={`font-semibold ${Number(attempt.marks) >= Number(exam.pass_marks) ? "text-green-700" : "text-red-600"}`}>
                            {Number(attempt.marks) >= Number(exam.pass_marks) ? "Passed" : "Not passed"}
                        </p>
                    )}
                    {attempt.remarks && <p className="text-sm text-gray-700 bg-gray-50 rounded-lg p-3 mt-3 text-left whitespace-pre-line"><b>Teacher's remarks:</b> {attempt.remarks}</p>}
                </div>
            )}
            {status === "graded" && (
                <Alert type="success">Your paper has been checked. The result will be shared with you soon.</Alert>
            )}

            <div className="bg-white rounded-xl shadow p-5 mb-5">
                <h2 className="font-semibold text-blue-900 mb-2">1. Question paper</h2>
                {exam.question_paper_url ? (
                    <a href={exam.question_paper_url} target="_blank" rel="noreferrer" download
                        className="inline-block bg-blue-900 text-white px-4 py-2 rounded-lg font-semibold hover:bg-blue-800">
                        Open / download question paper
                    </a>
                ) : <p className="text-gray-500">The question paper is not available yet.</p>}
                <p className="text-sm text-gray-500 mt-2">Write your answers on paper, then photograph or scan every page.</p>
            </div>

            <div className="bg-white rounded-xl shadow p-5">
                <h2 className="font-semibold text-blue-900 mb-2">2. Upload your answer sheets</h2>

                {attempt?.files?.length > 0 && (
                    <div className="mb-4">
                        <p className="text-sm text-gray-600 mb-2">Submitted {fmtDateTime(attempt.submitted_at)} · {attempt.files.length} page(s)</p>
                        <div className="grid grid-cols-3 sm:grid-cols-4 gap-2">
                            {attempt.files.map((f, i) => (
                                <a key={f.url} href={f.url} target="_blank" rel="noreferrer" className="border rounded-lg overflow-hidden block bg-gray-50">
                                    {isImg(f.name || f.url) ? <img src={f.url} alt={`Page ${i + 1}`} className="w-full h-24 object-cover" loading="lazy" /> : <div className="h-24 flex items-center justify-center text-gray-500 font-semibold">PDF</div>}
                                    <p className="text-xs p-1 text-center">Page {i + 1}</p>
                                </a>
                            ))}
                        </div>
                    </div>
                )}

                {!canUpload ? (
                    <p className="text-sm text-gray-500">
                        {locked ? "Your paper is already being evaluated, so it can no longer be changed." : exam.not_open_yet ? "Uploads open when the exam starts." : "The deadline has passed."}
                    </p>
                ) : (
                    <>
                        <p className="text-sm text-gray-500 mb-3">
                            Images or PDF, up to {MAX_FILES} pages, {MAX_MB} MB each. Pages are shown to the teacher in the order below.
                            {attempt && " Uploading again replaces your earlier submission."}
                        </p>
                        <div className="flex flex-wrap gap-2 mb-4">
                            <label className="inline-block bg-gray-200 hover:bg-gray-300 text-gray-800 px-4 py-2 rounded-lg font-semibold cursor-pointer">
                                Upload PDF
                                <input type="file" multiple accept="application/pdf" className="hidden" onChange={addFiles} />
                            </label>
                            <Button type="button" variant="ghost" onClick={openCamera}>Take photo (camera)</Button>
                            <label className="inline-block bg-gray-200 hover:bg-gray-300 text-gray-800 px-4 py-2 rounded-lg font-semibold cursor-pointer">
                                Choose photos
                                <input type="file" multiple accept="image/*" className="hidden" onChange={addFiles} />
                            </label>
                        </div>
                        {camError && <p className="text-sm text-red-600 mb-3">{camError}</p>}
                        <p className="text-xs text-gray-500 mb-4">Photos are joined into one PDF automatically when you submit.</p>

                        {picked.length > 0 && (
                            <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 mb-4">
                                {picked.map((p, i) => (
                                    <div key={`${p.file.name}-${i}`} className="border rounded-lg overflow-hidden bg-gray-50">
                                        {p.preview ? <img src={p.preview} alt={`Page ${i + 1}`} className="w-full h-32 object-cover" /> : <div className="h-32 flex items-center justify-center text-gray-500 font-semibold">PDF</div>}
                                        <div className="p-2 text-xs">
                                            <p className="truncate mb-1">Page {i + 1}: {p.file.name}</p>
                                            <div className="flex gap-2">
                                                <button type="button" className="text-blue-700" disabled={i === 0} onClick={() => move(i, -1)} aria-label="Move earlier">↑</button>
                                                <button type="button" className="text-blue-700" disabled={i === picked.length - 1} onClick={() => move(i, 1)} aria-label="Move later">↓</button>
                                                <button type="button" className="text-red-600 ml-auto" onClick={() => removeAt(i)}>Remove</button>
                                            </div>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        )}

                        <Button onClick={submit} disabled={busy || picked.length === 0}>
                            {busy ? "Creating PDF & sending..." : "Convert to PDF & send to teacher"}
                        </Button>
                    </>
                )}
            </div>

            {camOpen && (
                <div className="fixed inset-0 z-50 bg-black/80 flex flex-col items-center justify-center p-4">
                    <video ref={videoRef} autoPlay playsInline muted className="max-h-[70vh] max-w-full rounded-lg bg-black" />
                    <p className="text-white text-sm mt-3">{picked.length} page(s) captured. Place the sheet flat and well lit.</p>
                    <div className="flex gap-3 mt-3">
                        <Button type="button" onClick={snap}>Capture page</Button>
                        <Button type="button" variant="ghost" onClick={closeCamera}>Done</Button>
                    </div>
                </div>
            )}
        </div>
    );
}

export default PaperExam;