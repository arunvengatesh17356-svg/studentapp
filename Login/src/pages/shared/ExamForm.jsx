import { useEffect, useState } from "react";
import { useLocation, useNavigate, useParams } from "react-router-dom";
import { examsApi } from "../../services/api";
import { getStoredUser } from "../../utils/auth";
import { Alert, Button, Field, PageHeader, inputCls } from "../../components/ui";

const MAX_MB = 15;
const blankQ = () => ({ question_text: "", options: ["", "", "", ""], correct_option: 0, marks: 1, explanation: "" });
const toLocal = (v) => (v ? v.replace(" ", "T").slice(0, 16) : "");
const toServer = (v) => (v ? `${v.replace("T", " ")}:00` : null);

/*
| Create / edit an exam (admin + staff).
|   type "quiz"  -> MCQ questions built here, student answers online, auto-marked
|   type "paper" -> question paper file; student writes on paper and uploads photos/PDF; teacher marks
*/
function ExamForm() {
    const { id } = useParams();
    const editing = !!id;
    const navigate = useNavigate();
    const location = useLocation();
    const base = getStoredUser()?.role === "admin" ? "/admin/exams" : "/staff/exams";

    const [form, setForm] = useState({
        title: "", subject: "", type: "quiz", instructions: "", duration_minutes: 30,
        total_marks: 100, pass_marks: "", start_at: "", end_at: "",
        shuffle_questions: false, status: "published", batch_ids: [],
    });
    const [questions, setQuestions] = useState([blankQ()]);
    const [batches, setBatches] = useState([]);
    const [file, setFile] = useState(null);
    const [existingPaper, setExistingPaper] = useState("");
    const [loading, setLoading] = useState(editing);
    const [saving, setSaving] = useState(false);
    const [error, setError] = useState(location.state?.error || "");

    useEffect(() => {
        examsApi.targets().then((d) => setBatches(d.batches)).catch((e) => setError(e.message));
        if (!editing) return;
        examsApi.get(id).then(({ exam, questions: qs }) => {
            setForm({
                title: exam.title, subject: exam.subject || "", type: exam.type, instructions: exam.instructions || "",
                duration_minutes: exam.duration_minutes ?? "", total_marks: exam.total_marks, pass_marks: exam.pass_marks ?? "",
                start_at: toLocal(exam.start_at), end_at: toLocal(exam.end_at),
                shuffle_questions: !!Number(exam.shuffle_questions), status: exam.status,
                batch_ids: (exam.batch_ids || []).map(Number),
            });
            setExistingPaper(exam.question_paper_url || "");
            if (exam.type === "quiz" && qs?.length) {
                setQuestions(qs.map((q) => ({
                    question_text: q.question_text, options: q.options, correct_option: Number(q.correct_option),
                    marks: q.marks, explanation: q.explanation || "",
                })));
            }
        }).catch((e) => setError(e.message)).finally(() => setLoading(false));
    }, [id, editing]);

    const set = (k) => (e) => setForm((f) => ({ ...f, [k]: e.target.type === "checkbox" ? e.target.checked : e.target.value }));
    const toggleBatch = (bid) =>
        setForm((f) => ({ ...f, batch_ids: f.batch_ids.includes(bid) ? f.batch_ids.filter((x) => x !== bid) : [...f.batch_ids, bid] }));

    const setQ = (i, patch) => setQuestions((qs) => qs.map((q, j) => (j === i ? { ...q, ...patch } : q)));
    const setOpt = (i, oi, v) => setQ(i, { options: questions[i].options.map((o, k) => (k === oi ? v : o)) });
    const addOpt = (i) => questions[i].options.length < 6 && setQ(i, { options: [...questions[i].options, ""] });
    const delOpt = (i, oi) => {
        const q = questions[i];
        if (q.options.length <= 2) return;
        const correct = q.correct_option === oi ? 0 : q.correct_option > oi ? q.correct_option - 1 : q.correct_option;
        setQ(i, { options: q.options.filter((_, k) => k !== oi), correct_option: correct });
    };

    const quizTotal = questions.reduce((s, q) => s + (Number(q.marks) || 0), 0);

    const pickFile = (e) => {
        const f = e.target.files?.[0];
        if (!f) return;
        if (f.size > MAX_MB * 1024 * 1024) { setError(`File is larger than ${MAX_MB} MB`); e.target.value = ""; return; }
        setError("");
        setFile(f);
    };

    const validate = () => {
        if (!form.title.trim()) return "Enter the exam title";
        if (form.batch_ids.length === 0) return "Select at least one batch";
        if (form.start_at && form.end_at && form.end_at < form.start_at) return "Closing time must be after the opening time";
        if (form.type === "paper") {
            if (!file && !existingPaper) return "Upload the question paper";
            if (!(Number(form.total_marks) > 0)) return "Enter the total marks";
        } else {
            for (let i = 0; i < questions.length; i++) {
                const q = questions[i];
                if (!q.question_text.trim()) return `Question ${i + 1}: enter the question`;
                if (q.options.some((o) => !o.trim())) return `Question ${i + 1}: fill every option (or remove the empty ones)`;
                if (!(Number(q.marks) > 0)) return `Question ${i + 1}: marks must be more than 0`;
            }
        }
        return "";
    };

    const submit = async (e) => {
        e.preventDefault();
        const v = validate();
        if (v) { setError(v); window.scrollTo({ top: 0, behavior: "smooth" }); return; }
        setError("");
        setSaving(true);

        const isQuiz = form.type === "quiz";
        const payload = {
            title: form.title.trim(), subject: form.subject.trim(), type: form.type, instructions: form.instructions,
            duration_minutes: form.duration_minutes === "" ? null : Number(form.duration_minutes),
            total_marks: isQuiz ? quizTotal : Number(form.total_marks),
            pass_marks: form.pass_marks === "" ? null : Number(form.pass_marks),
            start_at: toServer(form.start_at), end_at: toServer(form.end_at),
            shuffle_questions: form.shuffle_questions ? 1 : 0, status: form.status, batch_ids: form.batch_ids,
            ...(isQuiz ? { questions: questions.map((q) => ({ ...q, marks: Number(q.marks), correct_option: Number(q.correct_option) })) } : {}),
        };

        let examId;
        try {
            const r = editing ? await examsApi.update(id, payload) : await examsApi.create(payload);
            examId = editing ? id : r.id;
        } catch (err) {
            setError(err.message); setSaving(false); window.scrollTo({ top: 0, behavior: "smooth" });
            return;
        }

        if (!isQuiz && file) {
            try {
                const fd = new FormData();
                fd.append("question_paper", file);
                await examsApi.uploadPaper(examId, fd);
            } catch (err) {
                // exam row exists now, so go to its edit page instead of risking a duplicate
                navigate(`${base}/${examId}/edit`, { replace: true, state: { error: `Exam saved, but the question paper upload failed: ${err.message}. Upload it again below.` } });
                setSaving(false);
                return;
            }
        }
        navigate(base, { state: { ok: editing ? "Exam updated" : "Exam created" } });
    };

    if (loading) return <p>Loading...</p>;
    const isQuiz = form.type === "quiz";

    return (
        <form onSubmit={submit} className="max-w-4xl">
            <PageHeader title={editing ? "Edit exam" : "New exam"} />
            <Alert>{error}</Alert>

            <div className="bg-white rounded-xl shadow p-5 mb-6">
                <h2 className="font-semibold text-blue-900 mb-3">Exam details</h2>

                <Field label="Exam type">
                    <div className="grid sm:grid-cols-2 gap-3">
                        {[
                            ["quiz", "Online quiz", "MCQ questions. Student answers on screen and the score is calculated automatically."],
                            ["paper", "Paper exam", "You give a question paper. Student writes on paper, uploads the answer sheets, and you mark them."],
                        ].map(([val, name, desc]) => (
                            <label key={val} className={`border rounded-lg p-3 cursor-pointer ${form.type === val ? "border-blue-900 bg-blue-50" : "border-gray-300"} ${editing ? "opacity-60 cursor-not-allowed" : ""}`}>
                                <input type="radio" name="type" className="mr-2" checked={form.type === val} disabled={editing}
                                    onChange={() => setForm((f) => ({ ...f, type: val }))} />
                                <span className="font-semibold">{name}</span>
                                <p className="text-sm text-gray-500 mt-1">{desc}</p>
                            </label>
                        ))}
                    </div>
                </Field>

                <div className="grid sm:grid-cols-2 gap-x-4">
                    <Field label="Title"><input className={inputCls} value={form.title} onChange={set("title")} required /></Field>
                    <Field label="Subject"><input className={inputCls} value={form.subject} onChange={set("subject")} placeholder="e.g. History" /></Field>
                    <Field label="Opens at (optional)"><input type="datetime-local" className={inputCls} value={form.start_at} onChange={set("start_at")} /></Field>
                    <Field label={isQuiz ? "Closes at (optional)" : "Due date & time (optional)"}><input type="datetime-local" className={inputCls} value={form.end_at} onChange={set("end_at")} /></Field>
                    {isQuiz ? (
                        <Field label="Time limit (minutes, blank = no limit)"><input type="number" min="1" className={inputCls} value={form.duration_minutes} onChange={set("duration_minutes")} /></Field>
                    ) : (
                        <Field label="Total marks"><input type="number" min="1" className={inputCls} value={form.total_marks} onChange={set("total_marks")} /></Field>
                    )}
                    <Field label="Pass marks (optional)"><input type="number" min="0" className={inputCls} value={form.pass_marks} onChange={set("pass_marks")} /></Field>
                </div>

                <Field label="Instructions for students">
                    <textarea rows={3} className={inputCls} value={form.instructions} onChange={set("instructions")} />
                </Field>

                {!isQuiz && (
                    <Field label={`Question paper (PDF or image, max ${MAX_MB} MB)`}>
                        <input type="file" accept="application/pdf,image/*" onChange={pickFile} className={inputCls} />
                        {existingPaper && !file && (
                            <a href={existingPaper} target="_blank" rel="noreferrer" className="text-sm text-blue-700 underline mt-1 inline-block">View current question paper</a>
                        )}
                    </Field>
                )}

                {isQuiz && (
                    <label className="flex items-center gap-2 mb-3 text-sm">
                        <input type="checkbox" checked={form.shuffle_questions} onChange={set("shuffle_questions")} />
                        Shuffle question order for each student
                    </label>
                )}

                <Field label="Status">
                    <select className={`${inputCls} max-w-[220px]`} value={form.status} onChange={set("status")}>
                        <option value="published">Published (students can see it)</option>
                        <option value="draft">Draft (hidden)</option>
                    </select>
                </Field>
            </div>

            <div className="bg-white rounded-xl shadow p-5 mb-6">
                <h2 className="font-semibold text-blue-900 mb-1">Assign to batches</h2>
                <p className="text-sm text-gray-500 mb-3">Every student in the selected batches gets this exam.</p>
                {batches.length === 0 ? <p className="text-gray-500">No batches available.</p> : (
                    <div className="grid sm:grid-cols-2 gap-2">
                        {batches.map((b) => (
                            <label key={b.id} className="flex items-center gap-2 border rounded-lg p-2 text-sm cursor-pointer">
                                <input type="checkbox" checked={form.batch_ids.includes(Number(b.id))} onChange={() => toggleBatch(Number(b.id))} />
                                <span>{b.batch_name}{b.course_name ? ` — ${b.course_name}` : ""}</span>
                            </label>
                        ))}
                    </div>
                )}
            </div>

            {isQuiz && (
                <div className="mb-6">
                    <div className="flex items-center justify-between mb-3 flex-wrap gap-2">
                        <h2 className="font-semibold text-blue-900">Questions ({questions.length}) · Total {quizTotal} marks</h2>
                        <Button type="button" variant="ghost" onClick={() => setQuestions((q) => [...q, blankQ()])}>+ Add question</Button>
                    </div>

                    {questions.map((q, i) => (
                        <div key={i} className="bg-white rounded-xl shadow p-5 mb-4">
                            <div className="flex items-center justify-between mb-2">
                                <p className="font-semibold">Question {i + 1}</p>
                                {questions.length > 1 && (
                                    <button type="button" className="text-sm text-red-600 hover:underline" onClick={() => setQuestions((qs) => qs.filter((_, j) => j !== i))}>Remove</button>
                                )}
                            </div>
                            <textarea rows={2} className={`${inputCls} mb-3`} placeholder="Type the question" value={q.question_text} onChange={(e) => setQ(i, { question_text: e.target.value })} />

                            <p className="text-sm text-gray-600 mb-1">Options (select the correct one)</p>
                            {q.options.map((o, oi) => (
                                <div key={oi} className="flex items-center gap-2 mb-2">
                                    <input type="radio" name={`correct-${i}`} checked={q.correct_option === oi} onChange={() => setQ(i, { correct_option: oi })} aria-label={`Option ${oi + 1} is correct`} />
                                    <input className={inputCls} placeholder={`Option ${oi + 1}`} value={o} onChange={(e) => setOpt(i, oi, e.target.value)} />
                                    {q.options.length > 2 && <button type="button" className="text-red-600 px-2" onClick={() => delOpt(i, oi)} aria-label="Remove option">✕</button>}
                                </div>
                            ))}
                            {q.options.length < 6 && (
                                <button type="button" className="text-sm text-blue-700 hover:underline mb-3" onClick={() => addOpt(i)}>+ Add option</button>
                            )}

                            <div className="grid sm:grid-cols-[120px_1fr] gap-x-4 mt-2">
                                <Field label="Marks"><input type="number" min="1" className={inputCls} value={q.marks} onChange={(e) => setQ(i, { marks: e.target.value })} /></Field>
                                <Field label="Explanation (optional, shown after result)"><input className={inputCls} value={q.explanation} onChange={(e) => setQ(i, { explanation: e.target.value })} /></Field>
                            </div>
                        </div>
                    ))}
                </div>
            )}

            <div className="flex gap-3">
                <Button type="submit" disabled={saving}>{saving ? "Saving..." : editing ? "Save changes" : "Create exam"}</Button>
                <Button type="button" variant="ghost" onClick={() => navigate(base)}>Cancel</Button>
            </div>
        </form>
    );
}

export default ExamForm;