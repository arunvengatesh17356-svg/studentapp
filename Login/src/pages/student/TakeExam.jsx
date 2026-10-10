import { useCallback, useEffect, useRef, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { myExamsApi } from "../../services/api";
import { Alert, Badge, Button, PageHeader } from "../../components/ui";

const mmss = (s) => `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
const draftKey = (attemptId) => `exam_draft_${attemptId}`;

/*
| Student takes an online quiz.
|   intro  -> instructions + Start
|   running-> one question at a time, countdown from the SERVER's seconds_left (so changing the
|             phone clock does not help), answers kept in localStorage so a refresh does not lose them
|   done   -> score (and review, if the backend sends it)
| The score goes to the staff/admin who created the exam; the backend does the marking.
*/
function TakeExam() {
    const { id } = useParams();
    const [exam, setExam] = useState(null);
    const [session, setSession] = useState(null); // { attempt_id, questions, seconds_left }
    const [answers, setAnswers] = useState({});
    const [idx, setIdx] = useState(0);
    const [left, setLeft] = useState(null);
    const [result, setResult] = useState(null);
    const [error, setError] = useState("");
    const [busy, setBusy] = useState(false);
    const [loading, setLoading] = useState(true);

    const answersRef = useRef({});
    const endRef = useRef(null);
    const doneRef = useRef(false);

    const begin = useCallback(async () => {
        setError(""); setBusy(true);
        try {
            const s = await myExamsApi.start(id);
            let saved = {};
            try { saved = JSON.parse(localStorage.getItem(draftKey(s.attempt_id))) || {}; } catch { /* ignore */ }
            answersRef.current = saved;
            setAnswers(saved);
            endRef.current = s.seconds_left != null ? Date.now() + s.seconds_left * 1000 : null;
            setLeft(s.seconds_left ?? null);
            setIdx(0);
            setSession(s);
        } catch (e) {
            setError(e.message);
        } finally {
            setBusy(false);
        }
    }, [id]);

    useEffect(() => {
        myExamsApi.get(id).then((d) => {
            setExam(d.exam);
            if (d.attempt && (d.attempt.status === "submitted" || d.attempt.status === "published")) {
                setResult(d.attempt.result || { pending: true });
            } else if (d.attempt?.status === "started") {
                begin(); // resume straight away
            }
        }).catch((e) => setError(e.message)).finally(() => setLoading(false));
    }, [id, begin]);

    const submit = useCallback(async (auto = false) => {
        if (doneRef.current || !session) return;
        if (!auto) {
            const unanswered = session.questions.filter((q) => answersRef.current[q.id] === undefined).length;
            const msg = unanswered ? `${unanswered} question(s) are not answered. Submit anyway?` : "Submit your exam now?";
            if (!confirm(msg)) return;
        }
        doneRef.current = true;
        setBusy(true);
        try {
            const r = await myExamsApi.submitQuiz(id, {
                attempt_id: session.attempt_id,
                answers: Object.entries(answersRef.current).map(([qid, opt]) => ({ question_id: Number(qid), selected_option: opt })),
            });
            localStorage.removeItem(draftKey(session.attempt_id));
            setResult(r.result || { pending: true });
            setSession(null);
        } catch (e) {
            doneRef.current = false;
            setError(e.message);
        } finally {
            setBusy(false);
        }
    }, [id, session]);

    // countdown
    useEffect(() => {
        if (!session || endRef.current == null) return;
        const t = setInterval(() => {
            const s = Math.max(0, Math.ceil((endRef.current - Date.now()) / 1000));
            setLeft(s);
            if (s === 0) { clearInterval(t); submit(true); }
        }, 500);
        return () => clearInterval(t);
    }, [session, submit]);

    // warn before closing the tab mid-exam
    useEffect(() => {
        if (!session) return;
        const h = (e) => { e.preventDefault(); e.returnValue = ""; };
        window.addEventListener("beforeunload", h);
        return () => window.removeEventListener("beforeunload", h);
    }, [session]);

    const choose = (qid, optIdx) => {
        const next = { ...answersRef.current, [qid]: optIdx };
        answersRef.current = next;
        setAnswers(next);
        try { localStorage.setItem(draftKey(session.attempt_id), JSON.stringify(next)); } catch { /* storage full/blocked */ }
    };

    if (loading) return <p>Loading...</p>;
    if (!exam) return <div><PageHeader title="Exam" /><Alert>{error}</Alert></div>;

    /* ---------- finished ---------- */
    if (result) {
        return (
            <div className="max-w-3xl">
                <PageHeader title={exam.title} action={<Link to="/my-exams" className="text-blue-700 hover:underline">← My exams</Link>} />
                <div className="bg-white rounded-xl shadow p-6 text-center mb-6">
                    {result.pending || result.marks == null ? (
                        <>
                            <p className="text-lg font-semibold text-blue-900">Exam submitted</p>
                            <p className="text-gray-500 mt-1">Your result will appear here once your teacher releases it.</p>
                        </>
                    ) : (
                        <>
                            <p className="text-gray-500">Your score</p>
                            <p className="text-5xl font-bold text-blue-900 my-2">{result.marks} <span className="text-2xl text-gray-400">/ {result.total_marks}</span></p>
                            <p className="text-sm text-gray-600">
                                {result.correct} correct · {result.wrong} wrong · {result.skipped} skipped
                            </p>
                            {exam.pass_marks != null && (
                                <p className={`mt-2 font-semibold ${Number(result.marks) >= Number(exam.pass_marks) ? "text-green-700" : "text-red-600"}`}>
                                    {Number(result.marks) >= Number(exam.pass_marks) ? "Passed" : "Not passed"}
                                </p>
                            )}
                        </>
                    )}
                </div>

                {result.review?.length > 0 && (
                    <div className="space-y-3">
                        <h2 className="font-semibold text-blue-900">Review</h2>
                        {result.review.map((q, i) => (
                            <div key={i} className="bg-white rounded-xl shadow p-4">
                                <p className="font-medium mb-2">{i + 1}. {q.question_text}</p>
                                {q.options.map((o, oi) => (
                                    <p key={oi} className={`text-sm px-2 py-1 rounded ${oi === q.correct_option ? "bg-green-100 text-green-800" : oi === q.selected ? "bg-red-100 text-red-700" : ""}`}>
                                        {o}{oi === q.correct_option ? " ✓" : oi === q.selected ? " (your answer)" : ""}
                                    </p>
                                ))}
                                {q.explanation && <p className="text-sm text-gray-600 mt-2">{q.explanation}</p>}
                            </div>
                        ))}
                    </div>
                )}
            </div>
        );
    }

    /* ---------- intro ---------- */
    if (!session) {
        return (
            <div className="max-w-2xl">
                <PageHeader title={exam.title} action={<Link to="/my-exams" className="text-blue-700 hover:underline">← My exams</Link>} />
                <Alert>{error}</Alert>
                <div className="bg-white rounded-xl shadow p-6">
                    <div className="flex gap-2 mb-3"><Badge>quiz</Badge></div>
                    <ul className="text-gray-700 space-y-1 mb-4">
                        <li>Subject: {exam.subject || "—"}</li>
                        <li>Questions: {exam.question_count}</li>
                        <li>Total marks: {exam.total_marks}</li>
                        <li>Time limit: {exam.duration_minutes ? `${exam.duration_minutes} minutes` : "None"}</li>
                    </ul>
                    {exam.instructions && <p className="whitespace-pre-line text-sm text-gray-600 bg-gray-50 rounded-lg p-3 mb-4">{exam.instructions}</p>}
                    <p className="text-sm text-amber-700 mb-4">
                        You can attempt this only once. The timer starts when you press Start and the exam is submitted automatically when time is up.
                    </p>
                    <Button onClick={begin} disabled={busy || !exam.is_open}>{busy ? "Starting..." : "Start exam"}</Button>
                    {!exam.is_open && <p className="text-sm text-gray-500 mt-2">{exam.not_open_yet ? "This exam is not open yet." : "This exam is closed."}</p>}
                </div>
            </div>
        );
    }

    /* ---------- running ---------- */
    const qs = session.questions;
    const q = qs[idx];
    const answered = qs.filter((x) => answers[x.id] !== undefined).length;

    return (
        <div className="max-w-4xl">
            <div className="sticky top-0 md:top-0 z-20 bg-gray-100 pb-3">
                <div className="flex items-center justify-between gap-3 bg-white rounded-xl shadow px-4 py-3 flex-wrap">
                    <div>
                        <p className="font-semibold text-blue-900">{exam.title}</p>
                        <p className="text-sm text-gray-500">{answered} / {qs.length} answered</p>
                    </div>
                    {left != null && (
                        <p className={`text-2xl font-mono font-bold ${left <= 60 ? "text-red-600" : "text-blue-900"}`} aria-live="off">{mmss(left)}</p>
                    )}
                </div>
            </div>

            <Alert>{error}</Alert>

            <div className="bg-white rounded-xl shadow p-5 mb-4">
                <p className="text-sm text-gray-500 mb-1">Question {idx + 1} of {qs.length} · {q.marks} mark{Number(q.marks) === 1 ? "" : "s"}</p>
                <p className="text-lg font-medium mb-4 whitespace-pre-line">{q.question_text}</p>
                <div className="space-y-2">
                    {q.options.map((o, oi) => (
                        <label key={oi} className={`flex items-start gap-3 border rounded-lg p-3 cursor-pointer ${answers[q.id] === oi ? "border-blue-900 bg-blue-50" : "border-gray-300 hover:bg-gray-50"}`}>
                            <input type="radio" name={`q-${q.id}`} className="mt-1" checked={answers[q.id] === oi} onChange={() => choose(q.id, oi)} />
                            <span>{o}</span>
                        </label>
                    ))}
                </div>
                {answers[q.id] !== undefined && (
                    <button type="button" className="text-sm text-gray-500 hover:underline mt-3" onClick={() => {
                        const next = { ...answersRef.current }; delete next[q.id];
                        answersRef.current = next; setAnswers(next);
                        try { localStorage.setItem(draftKey(session.attempt_id), JSON.stringify(next)); } catch { /* ignore */ }
                    }}>Clear my answer</button>
                )}
            </div>

            <div className="flex gap-3 mb-6 flex-wrap">
                <Button variant="ghost" disabled={idx === 0} onClick={() => setIdx(idx - 1)}>← Previous</Button>
                <Button variant="ghost" disabled={idx === qs.length - 1} onClick={() => setIdx(idx + 1)}>Next →</Button>
                <Button className="ml-auto" onClick={() => submit(false)} disabled={busy}>{busy ? "Submitting..." : "Submit exam"}</Button>
            </div>

            <div className="bg-white rounded-xl shadow p-4">
                <p className="text-sm text-gray-500 mb-2">Jump to question</p>
                <div className="flex flex-wrap gap-2">
                    {qs.map((x, i) => (
                        <button key={x.id} type="button" onClick={() => setIdx(i)} aria-label={`Question ${i + 1}`}
                            className={`w-9 h-9 rounded-lg text-sm font-semibold border ${i === idx ? "ring-2 ring-blue-900" : ""} ${answers[x.id] !== undefined ? "bg-blue-900 text-white border-blue-900" : "bg-white text-gray-700 border-gray-300"}`}>
                            {i + 1}
                        </button>
                    ))}
                </div>
            </div>
        </div>
    );
}

export default TakeExam;