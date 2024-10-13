const notify = (env, msg) => fetch(env.webhookUrl+"?wait=true", { method: "POST", body: JSON.stringify({ content: msg }), headers: { "content-type": "application/json" } });

const machinesToCheck = [ "compute03", "db2", "vps" ];

async function processMachine(env, m) {
	let mdata;
	try {
		mdata = await fetch(`http://${m}.pluralkit.net:19999/checks`);
		mdata = await mdata.json();
	} catch(e) {
		await notify(env, `<@&1291763746657669211>, on ${m}: failed to query checks status: ${e}`);
		return;
	}

	let out = [];

	if (isNaN(mdata.ts)) {
		out.push("- could not find last check timestamp");
	} else if (mdata.ts < (Date.now() / 1000 - 90)) {
		out.push(`- last check is too old (${mdata.ts - Date.now() / 1000} seconds ago)`);
	}

	if (!Array.isArray(mdata.errors)) {
		out.push("- could not find errors array");
	} else if (mdata.errors.length > 0) {
		out.unshift(...mdata.errors.map(e => `- ${e}`));
	}

if (out.length > 0) await notify(env, `<@&1291763746657669211>, on ${m}:\n${out.join("\n")} \n`);
	else console.log(`${m}: all checks ok!`);
}

export default {
	async scheduled(request, env, ctx): Promise<Response> {
// test
//		console.log(JSON.stringify(await notify(env, "test").then(x => x.json())));

		await Promise.all(machinesToCheck.map(m => processMachine(env, m)))

		console.log("cron processed!");
	},
} satisfies ExportedHandler<Env>;
