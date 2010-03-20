/* ui-repolist.c: functions for generating the repolist page
 *
 * Copyright (C) 2006 Lars Hjemli
 *
 * Licensed under GNU General Public License v2
 *   (see COPYING for full license text)
 */

/* This is needed for strcasestr to be defined by <string.h> */
#define _GNU_SOURCE 1
#include <string.h>

#include <time.h>

#include "cgit.h"
#include "html.h"
#include "ui-shared.h"

time_t read_agefile(char *path)
{
	time_t result;
	size_t size;
	char *buf;
	static char buf2[64];

	if (readfile(path, &buf, &size))
		return -1;

	if (parse_date(buf, buf2, sizeof(buf2)))
		result = strtoul(buf2, NULL, 10);
	else
		result = 0;
	free(buf);
	return result;
}

static int get_repo_modtime(const struct cgit_repo *repo, time_t *mtime)
{
	char *path;
	struct stat s;
	struct cgit_repo *r = (struct cgit_repo *)repo;

	if (repo->mtime != -1) {
		*mtime = repo->mtime;
		return 1;
	}
	path = fmt("%s/%s", repo->path, ctx.cfg.agefile);
	if (stat(path, &s) == 0) {
		*mtime = read_agefile(path);
		r->mtime = *mtime;
		return 1;
	}

	path = fmt("%s/refs/heads/%s", repo->path, repo->defbranch);
	if (stat(path, &s) == 0)
		*mtime = s.st_mtime;
	else
		*mtime = 0;

	r->mtime = *mtime;
	return (r->mtime != 0);
}

static void print_modtime(struct cgit_repo *repo)
{
	time_t t;
	if (get_repo_modtime(repo, &t))
		cgit_print_age(t, -1, NULL);
}

int is_match(struct cgit_repo *repo)
{
	if (!ctx.qry.search)
		return 1;
	if (repo->url && strcasestr(repo->url, ctx.qry.search))
		return 1;
	if (repo->name && strcasestr(repo->name, ctx.qry.search))
		return 1;
	if (repo->desc && strcasestr(repo->desc, ctx.qry.search))
		return 1;
	if (repo->owner && strcasestr(repo->owner, ctx.qry.search))
		return 1;
	return 0;
}

int is_in_url(struct cgit_repo *repo)
{
	if (!ctx.qry.url)
		return 1;
	if (repo->url && !prefixcmp(repo->url, ctx.qry.url))
		return 1;
	return 0;
}

void print_sort_header(const char *title, const char *sort)
{
	htmlf("<th class='left'><a href='%s?s=%s", cgit_rooturl(), sort);
	if (ctx.qry.search) {
		html("&q=");
		html_url_arg(ctx.qry.search);
	}
	htmlf("'>%s</a></th>", title);
}

void print_header(int columns)
{
	html("<tr class='nohover'>");
	print_sort_header("Name", "name");
	print_sort_header("Description", "desc");
	print_sort_header("Owner", "owner");
	print_sort_header("Idle", "idle");
	if (ctx.cfg.enable_index_links)
		html("<th class='left'>Links</th>");
	html("</tr>\n");
}


void print_pager(int items, int pagelen, char *search)
{
	int i;
	html("<div class='pager'>");
	for(i = 0; i * pagelen < items; i++)
		cgit_index_link(fmt("[%d]", i+1), fmt("Page %d", i+1), NULL,
				search, i * pagelen);
	html("</div>");
}

static int cmp(const char *s1, const char *s2)
{
	if (s1 && s2)
		return strcmp(s1, s2);
	if (s1 && !s2)
		return -1;
	if (s2 && !s1)
		return 1;
	return 0;
}

static int sort_section(const void *a, const void *b)
{
	const struct cgit_repo *r1 = a;
	const struct cgit_repo *r2 = b;
	int result;

	result = cmp(r1->section, r2->section);
	if (!result)
		result = cmp(r1->name, r2->name);
	return result;
}

static int sort_name(const void *a, const void *b)
{
	const struct cgit_repo *r1 = a;
	const struct cgit_repo *r2 = b;

	return cmp(r1->name, r2->name);
}

static int sort_desc(const void *a, const void *b)
{
	const struct cgit_repo *r1 = a;
	const struct cgit_repo *r2 = b;

	return cmp(r1->desc, r2->desc);
}

static int sort_owner(const void *a, const void *b)
{
	const struct cgit_repo *r1 = a;
	const struct cgit_repo *r2 = b;

	return cmp(r1->owner, r2->owner);
}

static int sort_idle(const void *a, const void *b)
{
	const struct cgit_repo *r1 = a;
	const struct cgit_repo *r2 = b;
	time_t t1, t2;

	t1 = t2 = 0;
	get_repo_modtime(r1, &t1);
	get_repo_modtime(r2, &t2);
	return t2 - t1;
}

struct sortcolumn {
	const char *name;
	int (*fn)(const void *a, const void *b);
};

struct sortcolumn sortcolumn[] = {
	{"section", sort_section},
	{"name", sort_name},
	{"desc", sort_desc},
	{"owner", sort_owner},
	{"idle", sort_idle},
	{NULL, NULL}
};

int sort_repolist(char *field)
{
	struct sortcolumn *column;

	for (column = &sortcolumn[0]; column->name; column++) {
		if (strcmp(field, column->name))
			continue;
		qsort(cgit_repolist.repos, cgit_repolist.count,
			sizeof(struct cgit_repo), column->fn);
		return 1;
	}
	return 0;
}


void cgit_print_repolist(void)
{
	int i, columns = 4, hits = 0, header = 0;
	char *last_section = NULL;
	char *section;
	int sorted = 0;

	if (ctx.cfg.enable_index_links)
		columns++;

	ctx.page.title = ctx.cfg.root_title;
	cgit_print_http_headers(&ctx);
	cgit_print_docstart(&ctx);
	cgit_print_pageheader(&ctx);

	if (ctx.cfg.index_header)
		html_include(ctx.cfg.index_header);

	if(ctx.qry.sort)
		sorted = sort_repolist(ctx.qry.sort);
	else
		sort_repolist("section");

	html("<table summary='repository list' class='list nowrap'>");
	for (i=0; i<cgit_repolist.count; i++) {
		ctx.repo = &cgit_repolist.repos[i];
		if (!(is_match(ctx.repo) && is_in_url(ctx.repo)))
			continue;
		hits++;
		if (hits <= ctx.qry.ofs)
			continue;
		if (hits > ctx.qry.ofs + ctx.cfg.max_repo_count)
			continue;
		if (!header++)
			print_header(columns);
		section = ctx.repo->section;
		if (section && !strcmp(section, ""))
			section = NULL;
		if (!sorted &&
		    ((last_section == NULL && section != NULL) ||
		    (last_section != NULL && section == NULL) ||
		    (last_section != NULL && section != NULL &&
		     strcmp(section, last_section)))) {
			htmlf("<tr class='nohover'><td colspan='%d' class='reposection'>",
			      columns);
			html_txt(section);
			html("</td></tr>");
			last_section = section;
		}
		htmlf("<tr><td class='%s'>",
		      !sorted && section ? "sublevel-repo" : "toplevel-repo");
		cgit_summary_link(ctx.repo->name, ctx.repo->name, NULL, NULL);
		html("</td><td>");
		html_link_open(cgit_repourl(ctx.repo->url), NULL, NULL);
		html_ntxt(ctx.cfg.max_repodesc_len, ctx.repo->desc);
		html_link_close();
		html("</td><td>");
		html_txt(ctx.repo->owner);
		html("</td><td>");
		print_modtime(ctx.repo);
		html("</td>");
		if (ctx.cfg.enable_index_links) {
			html("<td>");
			cgit_summary_link("summary", NULL, "button", NULL);
			cgit_log_link("log", NULL, "button", NULL, NULL, NULL,
				      0, NULL, NULL, ctx.qry.showmsg);
			cgit_tree_link("tree", NULL, "button", NULL, NULL, NULL);
			html("</td>");
		}
		html("</tr>\n");
	}
	html("</table>");
	if (!hits)
		cgit_print_error("No repositories found");
	else if (hits > ctx.cfg.max_repo_count)
		print_pager(hits, ctx.cfg.max_repo_count, ctx.qry.search);
	cgit_print_docend();
}

void cgit_print_site_readme(void)
{
	if (!ctx.cfg.root_readme)
		return;
	if (ctx.cfg.about_filter)
		cgit_open_filter(ctx.cfg.about_filter);
	html_include(ctx.cfg.root_readme);
	if (ctx.cfg.about_filter)
		cgit_close_filter(ctx.cfg.about_filter);
}
